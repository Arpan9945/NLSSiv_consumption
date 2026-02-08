*------------------------------------------------------------------------------*
*           Cleaning for housing/ rent part of consumption in NLSS			                   *
/*

	Author:				Arpan and Kapil
	Date created:		7th Feb 2026
	Date updated:		8th Feb 2026
	Last Updated by:	Arpan

	Notes:				Doing Hedonic regression here
			
	Dependencies:		Run 0_master before

*/

*------------------------------------------------------------------------------*
* STEP 3.2.3a: PREPARE DURABLES STOCK VALUE (FOR HOUSING REGRESSION)           *
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*
* STEP 3.2.3a: PREPARE DURABLES STOCK VALUE (FOR HOUSING REGRESSION)           *
*------------------------------------------------------------------------------*
use "$data_raw/S06C.dta", clear

* Calculate Total Value (Price * Quantity)
gen item_stock_value = q06_07 * q06_04
replace item_stock_value = 0 if item_stock_value == .

* Aggregate to Household Level
collapse (sum) durables_stock_value = item_stock_value, by(psu_number hh_number)

* Handle Zeros before taking Log (add small constant 1)
gen ln_durables_value = ln(durables_stock_value + 1)

label var durables_stock_value "Total Current Value of All Durables"
label var ln_durables_value "Log of Total Durable Value"

tempfile durables_stock
save `durables_stock'


*------------------------------------------------------------------------------*
* STEP 3.2.3b: PREPARE REGION & ACCESS VARIABLES                               *
*------------------------------------------------------------------------------*

*--- 1. PREPARE REGION (STRATA) ---*
use "$data_raw/poverty.dta", clear
keep psu_number hh_number ad_4

*Create the dummies
gen is_ktm   = (ad_4 == 1)
gen is_urban = (ad_4 == 2)
gen is_rural = (ad_4 == 3)

tempfile region_data
save `region_data'

*--- 2. PREPARE ACCESS TO FACILITIES (SECTION 3) ---*
use "$data_raw/S03.dta", clear


keep psu_number hh_number s03_code q03_03
duplicates drop psu_number hh_number s03_code, force


reshape wide q03_03, i(psu_number hh_number) j(s03_code)

rename q03_03101 dist_child_center     // Early Childhood Dev Center
rename q03_03102 dist_basic_school     // Basic School (1-8)
rename q03_03103 dist_sec_school       // Secondary School (12)
rename q03_03108 dist_gov_hospital     // Government Hospital
rename q03_03118 dist_bank             // Bank / Financial Inst
rename q03_03121 dist_police           // Police Station
rename q03_03122 dist_ward             // Ward Office

rename q03_03115 dist_market			// confused whether to use haatbazar (114) or main market center

tempfile access_data
save `access_data'

*------------------------------------------------------------------------------*
* STEP 3.2.3d: MERGE ALL AND REGRESS                                           *
*------------------------------------------------------------------------------*
use "$data_raw/S02.dta", clear

* MERGE DURABLES
merge 1:1 psu_number hh_number using `durables_stock'
keep if _merge == 3 // Keep matches
drop _merge

* 2. MERGE REGION
merge 1:1 psu_number hh_number using `region_data'
keep if _merge == 3
drop _merge

* 3. MERGE ACCESS TO FACILITIES
merge 1:1 psu_number hh_number using `access_data'
drop if _merge == 2
drop _merge


* --- DEFINE REGRESSION VARIABLES (MATCHING TABLE 3) ---

* Dependent Variable: Log Monthly Rent
* Use Actual Rent (q02_18) or Self-Reported (q02_13)
gen rent_monthly = .
replace rent_monthly = q02_18 if q02_18 > 0 & q02_18 < . 
replace rent_monthly = q02_13 if rent_monthly == . & q02_13 > 0

* Log and Outlier Removal (> 2 SD)
gen ln_rent_raw = ln(rent_monthly)
summarize ln_rent_raw
gen z_score = (ln_rent_raw - r(mean)) / r(sd)
replace ln_rent_raw = . if abs(z_score) > 2

* Housing Characteristics
gen ln_area = ln(q02_09)
gen num_rooms = q02_02_a

*Amenities
gen has_kitchen = (q02_02_b > 0 & q02_02_b != .)

gen has_cement_wall = (q02_04 == 2)
gen has_cement_foundation = (q02_05 == 2 | q02_05 == 3) //2 = Cement Bonded and 3 = Pillar bonded
gen has_strong_roof = (q02_06 == 1 | q02_06 == 2) 		//1= Galvanized Iron and 2 = Concrete Cement

* Utilities
gen has_piped_water      = (q02_21 == 1)
gen has_garbage_disposal = (q02_25 == 1 | q02_25 == 2) // Municipal or Private
gen has_sewage           = (q02_24 == 1)
gen has_electricity      = (q02_29 == 1)
gen has_landline         = (q02_31_a1 == 1)
gen has_internet         = (q02_31_c1 == 1)

* Renter Status & Interactions
gen is_renter = (q02_18 > 0 & q02_18 != .)
gen renter_ktm = (is_renter == 1 & is_ktm == 1)
gen renter_urban = (is_renter == 1 & is_urban == 1)
gen renter_rural = (is_renter == 1 & is_rural == 1)




* --- RUN HEDONIC REGRESSION ---
* Putting psu level fixed effect as well...

regress ln_rent_raw ln_area num_rooms has_kitchen has_cement_wall ///
        has_cement_foundation has_strong_roof has_piped_water ///
        has_garbage_disposal has_sewage has_electricity has_landline has_internet ///
        ln_durables_value renter_ktm renter_urban renter_rural ///
        dist_child_center dist_basic_school dist_sec_school ///
        dist_gov_hospital dist_bank dist_market dist_police dist_ward ///
        i.psu_number
// Here see if we can hide the results while viewing


* --- PREDICT & IMPUTE (DUAN'S SMEARING) ---
predict resid, residuals
gen exp_resid = exp(resid)
summarize exp_resid
local smearing_factor = r(mean)

predict ln_rent_hat, xb
gen predicted_rent_annual = exp(ln_rent_hat) * `smearing_factor' * 12
		
gen final_rent_annual = .
gen actual_rent_annual = q02_18 * 12

replace final_rent_annual = actual_rent_annual if is_renter == 1 & actual_rent_annual != .
replace final_rent_annual = predicted_rent_annual if final_rent_annual == .		
	
* Add Utilities (Water, Garbage, Electricity, Fuel)

gen util_water = q02_23
replace util_water = 0 if util_water == .
gen util_garbage = q02_26 * 12
replace util_garbage = 0 if util_garbage == .
gen util_elec = q02_30
replace util_elec = 0 if util_elec == .
// Firewood is excluded because it is said so


gen housing_aggregate_annual = final_rent_annual + util_water + util_garbage + util_elec

collapse (sum) housing_aggregate_annual, by(psu_number hh_number)
label var housing_aggregate_annual "Final Annual Housing Consumption"

save "$data_tmp/agg_housing_final.dta", replace

summarize housing_aggregate_annual, detail