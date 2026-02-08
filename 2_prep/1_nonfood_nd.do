*------------------------------------------------------------------------------*
*            	Cleaning for consumption in NLSS			                   *
/*

	Author:				Arpan and Kapil
	Date created:		7th Feb 2026
	Date updated:		7th Feb 2026
	Last Updated by:	Arpan

	Notes:				
			
	Dependencies:		Run 0_master before

*/


{
*------------------------------------------------------------------------------*
**#							STATA setups       								    
*------------------------------------------------------------------------------*
clear
cap clear frames
set more off
set rmsg on
local dofilename "01_data_merge"
cap log close
	
	*--------------------------------------------------------------------------*
	**# Import macros (global)
	
	*--------------------------------------------------------------------------*
	**# Export macros (global)
	
	*--------------------------------------------------------------------------*
	**# Programs
	
	*--------------------------------------------------------------------------*
	**# Macros check
	
	** No need to change following codes
	if "$workspace" == "" {
		di as error "Please set up workspace directory"
		exit
	} 
	
	*--------------------------------------------------------------------------*
	**# Date/time macro (global)
	
	** Following is useful for hourly log purpose
	local datehour =ustrregexra(regexr("`c(current_date)'"," 20","")+"_"+regexr("`c(current_time)'",":[0-9]+:[0-9]+","")," ","") //saves string in 4Mar23_13 format, equivalent to 4th march 2023, 13 hour.
	
*------------------------------------------------------------------------------*
**#							Log start       								    
*------------------------------------------------------------------------------*	
	
	log using "$log/`dofilename'_`datehour'", replace
	
}	
*------------------------------------------------------------------------------*
**#Load the dataset


display "======================================================================"
display "STEP 1: NON-FOOD NON-DURABLE AGGREGATE (S06A)"
display "======================================================================"

*------------------------------------------------------------------------------*
* STEP 1: NON-FOOD NON-DURABLE (SECTION 6A) - STRICT EXCLUSIONS                *
*------------------------------------------------------------------------------*

tempfile sec6a_agg

preserve 
    use "$data_raw/S06A.dta", clear

    *--------------------------------------------------------------------------*
    * A. DEFINE EXCLUSIONS (Based on Methodology Text)
    *--------------------------------------------------------------------------*
	
	gen is_header = mod(s06a_code, 10) == 0
    drop if is_header == 1
    
    * 1. DURABLES (Investments/Assets)
    * Furniture, Vehicles, Electronics, etc.
    local durables 511 512 531 532 541 551 711 712 713 714 ///
                   911 912 913 914 922 932 943 1231

    * 2. HEALTH EXPENSES but included education as well from 0955 (Defensive Expenditure - Excluded per Methodology)
    * 1051 = Preventive health care
    * 1052 = Treatment care (medicines, admission)
    local health_excluded 1051 1052

    * 3. NON-CONSUMPTION & LUMPY EXPENDITURES
    * 1241 = Donations (Transfer out)
    * 1251 = Life Insurance (Savings/Investment)
    * 1252 = Non-life Insurance (often excluded)
    * 1262 = Banking fees (Often considered service, but can be financial cost. We KEEP this usually as a service fee, unless "Interest payments")
    * 1271 = Registration/Renewal Fees (Taxes/Levies - Excluded)
    * 1272 = Legal Expenses (Often lumpy/admin - Excluded)
    * 1273 = Marriage/Death/Birth functions (Lumpy Life Events - Excluded)
    local lumpy_excluded 1241 1251 1252 1271 1272 1273

    * APPLY EXCLUSIONS
    foreach code of local durables {
        drop if s06a_code == `code'
    }
    foreach code of local health_excluded {
        drop if s06a_code == `code'
    }
    foreach code of local lumpy_excluded {
        drop if s06a_code == `code'
    }

    *--------------------------------------------------------------------------*
    * B. IDENTIFY EDUCATION (To be compared with S07 later)
    *--------------------------------------------------------------------------*
    * 1010-1040 = School Fees
    * 0955 = Academic Books
    * 1122 = Hostel Costs
    gen is_education_s06 = 0
    replace is_education_s06 = 1 if inlist(s06a_code, 1010, 1020, 1030, 1040, 0955, 1122)

    *--------------------------------------------------------------------------*
    * C. CLEANING & AGGREGATION
    *--------------------------------------------------------------------------*
    
    * Clean Missing Values
    replace q06_02a_b = 0 if q06_02a_b == .  // 30-day recall
    replace q06_02a_a = 0 if q06_02a_a == .  // 12-month recall

    * Calculate Annual Expenditure (Methodology 3.2.1)
    gen annualized_30 = q06_02a_b * 12
    
    * Calculate Medians
    bysort s06a_code: egen median_30_ann = median(annualized_30) if annualized_30 > 0
    bysort s06a_code: egen median_12 = median(q06_02a_a) if q06_02a_a > 0
    
    replace median_30_ann = 0 if median_30_ann == .
    replace median_12 = 0 if median_12 == .

    * Check Regularity (Diff <= 20%)
    gen pct_diff = abs(median_30_ann - median_12) / median_12 if median_12 > 0
    gen is_regular = 0
    replace is_regular = 1 if pct_diff <= 0.20 & pct_diff != .

    * Select Final Amount
    gen final_item_exp = .
    replace final_item_exp = annualized_30 if is_regular == 1
    replace final_item_exp = q06_02a_a if is_regular == 1 & final_item_exp == 0
    replace final_item_exp = q06_02a_a if is_regular == 0
    replace final_item_exp = annualized_30 if is_regular == 0 & final_item_exp == 0

    *--------------------------------------------------------------------------*
    * D. COLLAPSE TO HOUSEHOLD LEVEL (Splitting Education vs Other)
    *--------------------------------------------------------------------------*
    
    * Sum separately for Education and Non-Education
    collapse (sum) educ_s06_total = final_item_exp ///
                   nonfood_s06_other = final_item_exp, ///
             by(psu_number hh_number is_education_s06)
             
    * Flatten to 1 row per HH
    replace educ_s06_total = 0 if is_education_s06 == 0
    replace nonfood_s06_other = 0 if is_education_s06 == 1
    
    collapse (sum) educ_s06_total nonfood_s06_other, by(psu_number hh_number)

    label var educ_s06_total "Education Exp (Section 6A)"
    label var nonfood_s06_other "Other Non-Food Exp (S06A) - Excl Health/Taxes"

    save `sec6a_agg', replace
restore
display "Section 6A Finalized (Health & Lumpy Items Excluded)."







*------------------------------------------------------------------------------*
* STEP 2: EDUCATION (SECTION 7)                                                *
*------------------------------------------------------------------------------*
tempfile educ_s07_agg
preserve
    use "$data_raw/S07.dta", clear
    foreach var of varlist q07_17_a-q07_17_g {
        replace `var' = 0 if `var' == .
    }
    egen educ_individual_total = rowtotal(q07_17_a-q07_17_g)
    collapse (sum) educ_s07_total = educ_individual_total, by(psu_number hh_number)
    save `educ_s07_agg', replace
restore

*------------------------------------------------------------------------------*
* STEP 3: UTILITIES (SECTION 2)                                                *
*------------------------------------------------------------------------------*
tempfile util_agg
preserve
    use "$data_raw/S02.dta", clear
    
    * Clean missing
    replace q02_23 = 0 if q02_23 == .   // Water (Annual)
    replace q02_26 = 0 if q02_26 == .   // Garbage (Monthly)
    replace q02_30 = 0 if q02_30 == .   // Electricity (Annual)
    replace q02_31_a2 = 0 if q02_31_a2 == . // Landline (Annual)

    * Calculate Utilities (Annualize Garbage)
    gen utilities_annual = q02_23 + (q02_26 * 12) + q02_30 + q02_31_a2
    
    collapse (sum) utilities_annual, by(psu_number hh_number)
    save `util_agg', replace
restore

*------------------------------------------------------------------------------*
* STEP 4: FINAL MERGE                                                          *
*------------------------------------------------------------------------------*
use `sec6a_agg', clear

* Merge S07 (Education)
merge 1:1 psu_number hh_number using `educ_s07_agg'
drop _merge
replace educ_s07_total = 0 if educ_s07_total == .

* Merge S02 (Utilities)
merge 1:1 psu_number hh_number using `util_agg'
drop _merge
replace utilities_annual = 0 if utilities_annual == .

* COMPUTE FINAL AGGREGATES
* 1. Final Education = Max(Section 6A, Section 7)
gen educ_final = max(educ_s06_total, educ_s07_total)

* 2. Final Non-Food Non-Durable Aggregate
* Note: Health is EXCLUDED. Taxes are EXCLUDED.
gen agg_nonfood_nondurable = nonfood_s06_other + educ_final + utilities_annual

label var agg_nonfood_nondurable "Final Non-Food Non-Durable Aggregate (Annual)"

* Check
summarize agg_nonfood_nondurable, detail

* Save
save "$data_tmp/agg_nonfood_nondurable_final.dta", replace




