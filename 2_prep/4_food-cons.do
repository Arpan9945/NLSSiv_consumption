*------------------------------------------------------------------------------*
*           Cleaning for food consumption in NLSS			                   *
/*

	Author:				Arpan and Kapil
	Date created:		7th Feb 2026
	Date updated:		8th Feb 2026
	Last Updated by:	Arpan

	Notes:				
			
	Dependencies:		Run 0_master before

*/

*------------------------------------------------------------------------------*
* STEP 3.1: FOOD AWAY FROM HOME (SECTION 5 PART B)                             *
*------------------------------------------------------------------------------*

use "$data_raw/S05B.dta", clear

*Calculate total weekly expenditure per person

egen fah_weekly_indiv = rowtotal(q05_08_b q05_09_b q05_10_b q05_11_b q05_12_b q05_13_b q05_14_b q05_15)

collapse (sum) fah_weekly = fah_weekly_indiv, by (psu_number hh_number)

*Annualize it
gen fah_annual = fah_weekly * (365/7)
label var fah_weekly "Weekly Food Away From Home"
label var fah_annual "Annual Food Away From Home"

tempfile fah_data
save `fah_data'

summarize fah_annual, detail

*------------------------------------------------------------------------------*
* STEP 3.2: FOOD AT HOME (SECTION 5A) - CLEANING & IMPUTATION                  *
*------------------------------------------------------------------------------*
use "$data_raw/S05.dta", clear

merge m:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing(domain ad_4 hhs_wt)
keep if _merge == 3
drop _merge

* Define Hierarchy Variables
* We use 'domain' as the main stratum variable based on your file.
gen national = 1

gen conversion = 1
replace conversion = 0.001 if s05_unit == 1 // Grams -> Kg
replace conversion = 0.001 if s05_unit == 2 // ML -> Litre
replace conversion = 1.000 if s05_unit == 3 // Number -> Piece

* Convert Quantities
gen qty_mkt_std  = q05_04 * conversion
gen qty_home_std = q05_03 * conversion
gen qty_kind_std = q05_05 * conversion


*------------------------------------------------------------------------------*
* 3. CALCULATE UNIT VALUES (PRICE PER STANDARD UNIT)                           *
*------------------------------------------------------------------------------*
gen uv = q05_04_b / qty_mkt_std
replace uv = . if qty_mkt_std <= 0 | q05_04_b <= 0   //removing infinite or zero price

*------------------------------------------------------------------------------*
* 4. DETECT OUTLIERS (Z-SCORE METHOD)                                          *
*------------------------------------------------------------------------------*
gen ln_uv = ln(uv)

* Calculate Mean and SD of Price *by Item*
bysort food_code: egen mean_ln_uv = mean(ln_uv)
bysort food_code: egen sd_ln_uv = sd(ln_uv)

* Z-Score > 2.5 is an outlier
gen z_score = (ln_uv - mean_ln_uv) / sd_ln_uv
gen is_outlier = (abs(z_score) > 2.5) & (uv != .)

* Set Outlier Prices to Missing
replace uv = . if is_outlier == 1

*------------------------------------------------------------------------------*
* 5. CALCULATE MEDIAN PRICES (HIERARCHY)                                       *
*------------------------------------------------------------------------------*
* Hierarchy: PSU -> Domain -> Urban/Rural -> National

* A. PSU Median (Weighted by hhs_wt)
* (We use 'count' to ensure min 9 observations rule)
bysort psu_number food_code: egen count_psu = count(uv)
bysort psu_number food_code: egen median_psu = median(uv) 
replace median_psu = . if count_psu < 9 

* B. Domain Median
bysort domain food_code: egen median_domain = median(uv)

* C. Urban/Rural Median (ad_4)
bysort ad_4 food_code: egen median_ur = median(uv)

* D. National Median
bysort food_code: egen median_nat = median(uv)

* --- ASSIGN FINAL PRICE ---
gen final_price = .
replace final_price = median_psu
replace final_price = median_domain if final_price == .
replace final_price = median_ur     if final_price == .
replace final_price = median_nat    if final_price == .

* Fallback: If still missing, use original if valid
replace final_price = uv if final_price == . & uv != .

*------------------------------------------------------------------------------*
* 6. CALCULATE FINAL CONSUMPTION VALUES                                        *
*------------------------------------------------------------------------------*
* Reprice EVERYTHING using the median price (Methodology Requirement)

gen val_mkt_final  = qty_mkt_std * final_price
gen val_home_final = qty_home_std * final_price
gen val_kind_final = qty_kind_std * final_price

* Sum Components (Weekly)
egen food_weekly_total = rowtotal(val_mkt_final val_home_final val_kind_final)

*------------------------------------------------------------------------------*
* 7. AGGREGATE TO HOUSEHOLD LEVEL & ANNUALIZE                                  *
*------------------------------------------------------------------------------*
collapse (sum) food_weekly_total, by(psu_number hh_number)

* Annualize (Weeks * 52.14)
gen food_at_home_annual = food_weekly_total * (365/7)
label var food_at_home_annual "Annual Food Consumption (At Home)"

*------------------------------------------------------------------------------*
* 8. MERGE WITH FOOD AWAY FROM HOME & SAVE                                     *
*------------------------------------------------------------------------------*
* Ensure you have run the FAH code and saved `fah_data` or a tempfile
merge 1:1 psu_number hh_number using `fah_data'
drop if _merge == 2
drop _merge

replace fah_annual = 0 if fah_annual == .
gen food_aggregate_annual = food_at_home_annual + fah_annual
label var food_aggregate_annual "Final Nominal Annual Food Consumption"

save "$data_tmp/agg_food_final.dta", replace

summarize food_aggregate_annual, detail