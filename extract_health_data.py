"""
NJ Health Equity Access Analytics Dashboard
Data Extraction Pipeline · Lunarix Technologies LLC · Yiduo Xiao

Sources:
  1. CDC PLACES API (county-level health measures, NJ)
  2. US Census ACS API (insurance coverage)
  3. HRSA Data Warehouse (provider shortage areas)
  4. Local SQLite DB (schema + seed data)

Run: python extract_health_data.py
Output: data/ folder with Tableau-ready CSVs

J&J alignment: Race to Health Equity ESG pillar
"""

import sqlite3, os, json, time
import pandas as pd
import requests
from datetime import datetime

DB_PATH = "nj_health.db"
OUT     = "data"
os.makedirs(OUT, exist_ok=True)

# ── STEP 1: Init DB ──────────────────────────────────────────
def init_db():
    conn = sqlite3.connect(DB_PATH)
    with open("nj_health_schema.sql") as f:
        conn.executescript(f.read())
    conn.commit()
    print(f"[OK] DB initialized · {DB_PATH}")
    return conn

# ── STEP 2: CDC PLACES API (live pull) ───────────────────────
def fetch_cdc_places():
    """
    CDC PLACES 2023 — county-level health measures for NJ
    API: https://data.cdc.gov/resource/swc5-untb.json
    Socrata Open Data API (no key required for <1000 rows)
    """
    url = "https://data.cdc.gov/resource/swc5-untb.json"
    measures = [
        "DIABETES",     # Diabetes prevalence
        "BPHIGH",       # High blood pressure
        "DEPRESSION",   # Depression
        "CANCER",       # Cancer (excluding skin)
        "CHECKUP",      # Annual checkup (preventive access)
        "DENTAL",       # Dental visit past year
        "MAMMOUSE",     # Mammography screening
        "OBESITY",      # Obesity
    ]
    print("\n[STEP 2] Fetching CDC PLACES data...")
    all_rows = []
    for measure in measures:
        params = {
            "stateabbr": "NJ",
            "measureid": measure,
            "geographiclevel": "County",
            "$limit": 25
        }
        try:
            r = requests.get(url, params=params, timeout=10)
            if r.status_code == 200:
                data = r.json()
                all_rows.extend(data)
                print(f"  ✓ {measure}: {len(data)} counties")
            else:
                print(f"  ✗ {measure}: HTTP {r.status_code} — using seed data")
        except Exception as e:
            print(f"  ✗ {measure}: {e} — using seed data")
        time.sleep(0.3)

    if all_rows:
        df = pd.DataFrame(all_rows)
        cols = ["locationname","measureid","measure","data_value",
                "low_confidence_limit","high_confidence_limit",
                "totalpopulation","geographiclevel","year"]
        available = [c for c in cols if c in df.columns]
        df = df[available]
        path = f"{OUT}/cdc_places_raw.csv"
        df.to_csv(path, index=False)
        print(f"  [OK] CDC PLACES → {path} ({len(df)} rows)")
        return df
    else:
        print("  [INFO] No live data — seed data in DB will be used")
        return None

# ── STEP 3: Census ACS (insurance coverage) ──────────────────
def fetch_census_acs():
    """
    ACS 5-Year Estimates — Table S2701 (Health Insurance)
    API: https://api.census.gov/data/2022/acs/acs5/subject
    No API key required for basic queries
    """
    print("\n[STEP 3] Fetching Census ACS insurance data...")
    url = "https://api.census.gov/data/2022/acs/acs5/subject"
    params = {
        "get": "S2701_C04_001E,S2701_C05_001E,NAME",  # insured/uninsured
        "for": "county:*",
        "in": "state:34"  # NJ FIPS = 34
    }
    try:
        r = requests.get(url, params=params, timeout=10)
        if r.status_code == 200:
            raw = r.json()
            df = pd.DataFrame(raw[1:], columns=raw[0])
            path = f"{OUT}/census_insurance_raw.csv"
            df.to_csv(path, index=False)
            print(f"  [OK] ACS insurance → {path} ({len(df)} counties)")
            return df
        else:
            print(f"  [INFO] Census API HTTP {r.status_code} — using seed data")
    except Exception as e:
        print(f"  [INFO] Census API: {e} — using seed data")
    return None

# ── STEP 4: Export Tableau-ready flat files ───────────────────
def export_tableau(conn):
    print("\n[STEP 4] Exporting Tableau-ready files...")
    exports = {
        "tableau_county_dashboard": "SELECT * FROM v_county_dashboard",
        "tableau_racial_disparity": "SELECT * FROM v_racial_disparity",
        "tableau_jnj_market":       "SELECT * FROM v_jnj_market_opportunity",
    }
    for name, query in exports.items():
        df = pd.read_sql_query(query, conn)
        path = f"{OUT}/{name}.csv"
        df.to_csv(path, index=False)
        print(f"  [OK] {name}.csv — {len(df)} rows")
    return

# ── STEP 5: Disparity summary ─────────────────────────────────
def disparity_summary(conn):
    print("\n[STEP 5] Racial disparity analysis...")
    df = pd.read_sql_query("SELECT * FROM v_racial_disparity", conn)
    print(f"\n  Top 5 counties by Black-White insurance gap:")
    print(df[["county_name","black_white_gap","hispanic_white_gap"]
             ].head(5).to_string(index=False))

    # Counties flagged as HPSA (provider shortage)
    hpsa = pd.read_sql_query("""
        SELECT c.county_name, p.hpsa_primary_care, p.hpsa_mental_health,
               p.hpsa_dental, p.primary_care_per_10k
        FROM provider_availability p
        JOIN nj_counties c ON p.fips=c.fips
        WHERE p.hpsa_primary_care=1 OR p.hpsa_mental_health=1
        ORDER BY p.primary_care_per_10k ASC
    """, conn)
    print(f"\n  Counties with HRSA provider shortage designation:")
    print(hpsa.to_string(index=False))

    path = f"{OUT}/disparity_summary.csv"
    df.to_csv(path, index=False)
    print(f"\n  [OK] disparity_summary.csv → {path}")

# ── STEP 6: Tableau connection guide ─────────────────────────
def print_tableau_guide():
    guide = """
╔══════════════════════════════════════════════════════════════════╗
║  TABLEAU CHOROPLETH MAP SETUP — NJ County Health Equity          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  File: data/tableau_county_dashboard.csv                         ║
║                                                                  ║
║  Step 1 — Connect CSV to Tableau                                 ║
║  · Connect → Text File → tableau_county_dashboard.csv           ║
║                                                                  ║
║  Step 2 — Create NJ County map                                   ║
║  · Double-click "county_name" field → Tableau auto-generates map ║
║  · OR: Marks → Map → choose Filled Map                          ║
║  · Geographic role: county_name → County (assign state = NJ)    ║
║                                                                  ║
║  Step 3 — Color by metric                                        ║
║  · Drag "uninsured_pct" to Color Marks card                     ║
║  · Color: Diverging (blue = low uninsured, red = high)          ║
║  · Switch to: access_tier for categorical coloring               ║
║                                                                  ║
║  Step 4 — Tooltip with key stats                                 ║
║  · Add to Tooltip: county_name, uninsured_pct, access_tier,     ║
║    primary_care_per_10k, diabetes_pct, median_income             ║
║                                                                  ║
║  Step 5 — Dashboard assembly (4 sheets)                          ║
║  · Sheet 1: NJ choropleth — uninsured rate by county            ║
║  · Sheet 2: Bar chart — racial disparity gaps (top 10 counties) ║
║  · Sheet 3: Scatter — median income vs. uninsured rate          ║
║  · Sheet 4: Disease burden — diabetes + hypertension by region  ║
║                                                                  ║
║  Calculated fields to add in Tableau:                            ║
║  · [Disparity Gap] = [uninsured_hispanic] - [uninsured_pct]     ║
║  · [Provider Gap] = 100 - [primary_care_per_10k] / 1.2         ║
║  · [J&J Opportunity Score] =                                    ║
║       [diabetes_pct]*0.4 + [uninsured_pct]*0.4 +               ║
║       (100-[coverage_score])*0.2                                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
    """
    print(guide)

# ── MAIN ─────────────────────────────────────────────────────
if __name__ == "__main__":
    print("NJ Health Equity Dashboard — Data Pipeline")
    print("=" * 55)
    conn    = init_db()
    fetch_cdc_places()
    fetch_census_acs()
    export_tableau(conn)
    disparity_summary(conn)
    print_tableau_guide()
    conn.close()
    print("\n[DONE] All files in /data/ · Ready for Tableau")
