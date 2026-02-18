*------------------------------------------------------------------------------*
*            Cleaning for Health Expenses related stuffs in NLSS			                   *
/*

	Author:				Arpan 
	Date created:		10th Feb 2026
	Date updated:		10th Feb 2026
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
	// "$data_tmp/health_disease_individual.dta"
	// "$data_tmp/health_financial_protection_hh.dta"
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
**# Load the dataset
use "$data_raw/S08.dta", clear


foreach var in q08_06_i q08_14_i {
    replace `var' = 0 if `var' == .
}

*------------------------------------------------------------------------------*
**# 1. Convert Health Costs to Monthly
*------------------------------------------------------------------------------*
* Chronic (q08_06) is usually 12-month recall -> Divide by 12
* Acute (q08_14) is usually 30-day recall -> Keep as is

gen health_cost_person_month = (q08_06_i / 12) + q08_14_i


**# Distress Financing
* Want to see how the household financed their health cost
local distress_codes "2 3"

gen distress_chronic = 0
foreach c of local distress_codes {
    replace distress_chronic = 1 if q08_07 == `c'
}

gen distress_acute = 0
foreach c of local distress_codes {
    replace distress_acute = 1 if q08_15 == `c'
}

gen distress_person = (distress_chronic == 1 | distress_acute == 1)

* Collapse to Household Level
* Note: We are now summing the MONTHLY health cost
collapse (sum) health_exp_hh_month = health_cost_person_month /// Sum of monthly costs
         (max) distress_hh = distress_person /// If ANY member used distress finance
         , by(psu_number hh_number)

* Label them nicely
label var health_exp_hh_month "Total Monthly Household Health Expenditure"
label var distress_hh "Did HH use distress financing (Loans/Assets)?"

* Merge Consumption Data
merge 1:1 psu_number hh_number using "$data_tmp/final_nominal_consumption.dta", keepusing(total_nom_cons)
drop _merge
merge 1:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing (psu_number hh_number prov ad_4 prov domain ad_4 poor pcep quintile_pcep hhs_wt ind_wt hhsize pcep_food pcep_nonfood pcep poor)
drop _merge

replace health_exp_hh_month = 0 if health_exp_hh_month == .
replace distress_hh = 0 if distress_hh == .

*------------------------------------------------------------------------------*
**# 2. Convert Consumption to Monthly
*------------------------------------------------------------------------------*
* PCEP variables in NLSS poverty files are ANNUAL. 
* We calculate Total HH Annual first, then divide by 12.

gen total_hh_cons_month   = (pcep * hhsize) / 12
gen total_hh_nonfood_month = (pcep_nonfood * hhsize) / 12
gen total_hh_food_month    = (pcep_food * hhsize) / 12

*------------------------------------------------------------------------------*
**# 3. Calculate Shares (Monthly Basis)
*------------------------------------------------------------------------------*

gen health_share_total  = (health_exp_hh_month / total_hh_cons_month) * 100
gen health_share_nf     = (health_exp_hh_month / total_hh_nonfood_month) * 100

* Catastrophic Expenditure Indicators
gen che_10 = (health_share_total > 10)
gen che_15 = (health_share_total > 15)
gen che_25 = (health_share_total > 25)
gen che_40 = (health_share_nf > 40)

** Analysis Part
gen pop_wt = hhs_wt * hhsize

*------------------------------------------------------------------------------*
**# 4. Tables
*------------------------------------------------------------------------------*

di "--- Percent of Households in Catastrophe (By Consumption Quintile) ---"
* 2.i. Catastrophe (>10% Total Monthly Spending)
table quintile [iw=pop_wt], stat(mean che_10) nformat(%9.3f) 
* 2.ii. Catastrophe (>15% Total Monthly Spending)
table quintile [iw=pop_wt], stat(mean che_15) nformat(%9.3f) 
* 2.iii. Catastrophe (>25% Total Monthly Spending)
table quintile [iw=pop_wt], stat(mean che_25) nformat(%9.3f) 
* 2.iv. Catastrophe (>40% Non-Food Monthly Spending)
table quintile [iw=pop_wt], stat(mean che_40) nformat(%9.3f) 

di "--- Percent of Households in Catastrophe (By Poverty Status) ---"
* 3.i. Catastrophe (>10% Total Monthly Spending)
table poor [iw=pop_wt], stat(mean che_10) nformat(%9.3f) 
* 3.ii. Catastrophe (>15% Total Monthly Spending)
table poor [iw=pop_wt], stat(mean che_15) nformat(%9.3f) 
* 3.iii. Catastrophe (>25% Total Monthly Spending)
table poor [iw=pop_wt], stat(mean che_25) nformat(%9.3f) 
* 3.iv. Catastrophe (>40% Non-Food Monthly Spending)
table poor [iw=pop_wt], stat(mean che_40) nformat(%9.3f) 


* 3. Percent of Households utilizing Distress Financing
table quintile [iw=pop_wt], stat(mean distress_hh) nformat(%9.3f)


* Label the dataset 
label data "NLSS-IV Household Financial Protection Indicators (Monthly Basis)"
save "$data_tmp/health_financial_protection_hh.dta", replace


*------------------------------------------------------------------------------*
**# INDIVIDUAL DATA SECTION (Unchanged, but kept for completeness)
*------------------------------------------------------------------------------*
use "$data_raw/S08.dta", clear
merge m:1 psu_number hh_number using "$data_tmp/final_nominal_consumption.dta", keepusing(total_nom_cons)
drop _merge
merge m:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing (psu_number hh_number prov ad_4 prov domain ad_4 poor pcep quintile_pcep hhs_wt ind_wt hhsize)
drop _merge

gen pop_wt = hhs_wt * hhsize

gen chronic_illness = 0
replace chronic_illness = 1 if q08_02 == 1

gen acute_illness = 0
replace acute_illness = 1 if q08_10 == 1

table quintile [iw=pop_wt], stat(mean chronic_illness acute_illness) nformat(%9.3f)

label data "NLSS-IV Individual Disease Prevalence (Chronic/Acute)"
save "$data_tmp/health_disease_individual.dta", replace