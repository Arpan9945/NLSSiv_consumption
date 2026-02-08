* Define Paths
global raw_path "C:\Users\Arpan Acharya\OneDrive - HERD\Documents\Personal\CIH-project\1_raw"
global temp_path "C:\Users\Arpan Acharya\OneDrive - HERD\Documents\Personal\CIH-project\2_temp"

* 1. Load Data
use "$raw_path\S05.dta", clear

* 2. Clean Missing Values (Treat dots as zero)
foreach var in q05_03_b q05_04_b q05_05_b {
    replace `var' = 0 if `var' == .
}

* 3. Calculate Item Value (Row by Row)
gen item_val = q05_03_b + q05_04_b + q05_05_b

* 4. Aggregate by Household (Using bysort/egen)
* This puts the TOTAL food value in every row for that household
bysort psu_number hh_number: egen food_7day_total = total(item_val)

* 5. Annualize
gen agg_food_annual = food_7day_total * 52
label var agg_food_annual "Annual Food Consumption"

* 6. Reduce to Household Level
* Since every row for the household now has the same total, we only need the first one.
bysort psu_number hh_number: keep if _n == 1

* 7. Keep only what we need and Save
keep psu_number hh_number agg_food_annual
sort psu_number hh_number
save "$temp_path\temp_food_agg.dta", replace

display "Section 5 (Food) Completed."




* Non- Food


* --- Load Frequent Non-Food Data (30-Day Recall) ---
use "$raw_path\S06A.dta", clear

* 1. Identify the "Value" variable
* Usually named 'q06_02_b' or similar (Value purchased in last 30 days)
* Look for the variable with label "RUPEES" or "VALUE".
* UPDATE the variable name below if it's different.
local nonfood_30_val q06_02_b 

* 2. Clean Missing Values
capture confirm variable `nonfood_30_val'
if _rc == 0 {
    replace `nonfood_30_val' = 0 if `nonfood_30_val' == .
}

* 3. Aggregate by Household
bysort psu_number hh_number: egen nonfood_30day_total = total(`nonfood_30_val')

* 4. Annualize (30 days * 12 months)
gen agg_nonfood_freq_annual = nonfood_30day_total * 12
label var agg_nonfood_freq_annual "Annual Frequent Non-Food"

* 5. Keep One Row per Household & Save
bysort psu_number hh_number: keep if _n == 1
keep psu_number hh_number agg_nonfood_freq_annual
save "$temp_path\temp_nonfood_freq.dta", replace

display "Section 6A (Frequent Non-Food) Complete."