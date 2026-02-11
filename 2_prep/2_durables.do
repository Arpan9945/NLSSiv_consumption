*------------------------------------------------------------------------------*
* STEP 3.2.2: DURABLES CONSUMPTION FLOW (USER COST) - EXCEL VERSION            *
*------------------------------------------------------------------------------*

import excel "$data_raw/CPI_2022.xlsx", sheet("Sheet1") firstrow clear

rename year purchase_year
tostring purchase_year, replace

summarize cpi if purchase_year == "2022"
local cpi_2022 = r(mean)
gen cpi_factor = `cpi_2022' / cpi


tempfile cpi_data
save `cpi_data', replace


*------------------------------------------------------------------------------*
* 2. LOAD & PROCESS DURABLES DATA (S06C)
*------------------------------------------------------------------------------*
use "$data_raw/S06C.dta", clear


* Exclude: 522 (Watch), 523 (Furniture), 524 (Utensils) and only the household owning them
keep if s06c_code >= 501 & s06c_code <= 521
keep if q06_03c == 1

replace q06_04 = 1 if q06_04 == . | q06_04 == 0

replace q06_05a = 0 if q06_05a == . 
gen purchase_year_num = 2022 - q06_05a

tostring purchase_year_num, generate(purchase_year)
replace purchase_year = trim(purchase_year)


* Merge with CPI data
merge m:1 purchase_year using `cpi_data'

/*
  Result                      Number of obs
    -----------------------------------------
    Not matched                            11
        from master                         4  (_merge==1)
        from using                          7  (_merge==2)

    Matched                            34,336  (_merge==3)
    -----------------------------------------
	
	Here 4 of the observations are not merged because there are items from 1957, 1959, 1962
*/

*------------------------------------------------------------------------------*
* Post merge fix (ignore if needed)
*------------------------------------------------------------------------------*

	drop if _merge == 2 

	* Fix the 4 old items (1957, 1959, 1962) using 1972 data
	* We grab the factor for 1972 from the successful matches
	summarize cpi_factor if purchase_year == "1972"
	local factor_1972 = r(mean)

	* Apply this factor to the unmatched items (where _merge == 1)
	replace cpi_factor = `factor_1972' if _merge == 1 & cpi_factor == .

	drop _merge

*------------------------------------------------------------------------------*
* 2. CALCULATE REAL VALUE & DEPRECIATION
*------------------------------------------------------------------------------*

gen real_purchase_value = q06_05b * cpi_factor

* Calculate Depreciation (Delta)
* Formula: delta = 1 - (Current_Value / Real_Purchase_Value) ^ (1/Age)
* Use Age=1 for new items to avoid division by zero
gen age_calc = max(q06_05a, 1)
gen ratio = q06_07 / real_purchase_value
gen delta_raw = 1 - (ratio)^(1/age_calc)

* Clean outliers 
* Delta cannot be > 1 (value dropped to zero instantly) or < 0 (value increased)
replace delta_raw = . if delta_raw > 1 | delta_raw < 0
replace delta_raw = . if real_purchase_value <= 0


* Define Age Groups (0-1, 2-3, 4-5, 6-10, 10+)
*This is mentioned in the methodology and one of the advancement from previous years

gen age_group = .
replace age_group = 1 if q06_05a <= 1           
replace age_group = 2 if q06_05a >= 2 & q06_05a <= 3
replace age_group = 3 if q06_05a >= 4 & q06_05a <= 5
replace age_group = 4 if q06_05a >= 6 & q06_05a <= 10
replace age_group = 5 if q06_05a > 10

bysort s06c_code age_group: egen median_delta = median(delta_raw)

* Fill missing medians with item's overall median, then global default (0.2)
bysort s06c_code: egen global_item_median = median(delta_raw)
replace median_delta = global_item_median if median_delta == .
replace median_delta = 0.20 if median_delta == .


*------------------------------------------------------------------------------*
* 4. CALCULATE USER COST (CONSUMPTION FLOW)
*------------------------------------------------------------------------------*

* Formula: UserCost = (CurrentValue * Qty) * ( (r + delta) / (1 - delta) )
**# Real Interest Rate = 0.05 (Update Later after looking the actual figures)
scalar r_real = 0.05

gen current_val_total = q06_07 * q06_04
gen user_cost_item = current_val_total * ( (r_real + median_delta) / (1 - median_delta) )

* Handle missings
replace user_cost_item = 0 if user_cost_item == .

*------------------------------------------------------------------------------*
* 5. AGGREGATE TO HOUSEHOLD LEVEL
*------------------------------------------------------------------------------*
collapse (sum) durables_flow_annual = user_cost_item, by(psu_number hh_number)

label var durables_flow_annual "Annual Consumption Flow from Durables (User Cost)"

* Check stats
summarize durables_flow_annual, detail

* Save
save "$data_tmp/agg_durables_final.dta", replace

display "SUCCESS: Durables Flow (Section 3.2.2) Complete."