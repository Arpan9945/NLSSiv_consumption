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
**#Load the dataset
use "$data_raw/S08.dta", clear


foreach var in q08_06_i q08_14_i {
    replace `var' = 0 if `var' == .
}

* Calculate Total Health Cost for this Person (Chronic + Acute)
gen health_cost_person = q08_06_i + q08_14_i


**#1- Idea one is about distress financing.
*Want to see how the household financed their health cost

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
collapse (sum) health_exp_hh = health_cost_person /// Sum of all costs
         (max) distress_hh = distress_person /// If ANY member used distress finance, HH is 1
         , by(psu_number hh_number)

* Label them nicely
label var health_exp_hh "Total Annual Household Health Expenditure (Nominal)"
label var distress_hh "Did HH use distress financing (Loans/Assets) for health?"

merge 1:1 psu_number hh_number using "$data_tmp/final_nominal_consumption.dta", keepusing(total_nom_cons)
drop _merge
merge 1:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing (psu_number hh_number prov ad_4 prov domain ad_4 poor pcep quintile_pcep hhs_wt ind_wt hhsize pcep_food pcep_nonfood pcep poor)
drop _merge

replace health_exp_hh = 0 if health_exp_hh == .
replace distress_hh = 0 if distress_hh == .

* Calculating the indicators
gen total_hh_cons_real = pcep * hhsize
gen total_hh_nonfood = pcep_nonfood * hhsize
gen total_hh_food = pcep_food * hhsize


gen health_share_real = (health_exp_hh / total_hh_cons_real) * 100
gen health_share_nf   = (health_exp_hh/ total_hh_nonfood) * 100

*Catastrophic Expenditure (Threshold = 10% of Total Budget)
gen che_10 = (health_share_real > 10)
gen che_15 = (health_share_real > 15)
gen che_25 = (health_share_real > 25)
gen che_40 = (health_share_nf	> 40)

** Analysis Part

gen pop_wt = hhs_wt * hhsize


* 2.i. Percent of Households in "Catastrophe" (>10% spending)
table quintile [iw=pop_wt], stat(mean che_10) nformat(%9.3f) 
* 2.ii. Percent of Households in "Catastrophe" (>15% spending)
table quintile [iw=pop_wt], stat(mean che_15) nformat(%9.3f) 
* 2.iii. Percent of Households in "Catastrophe" (>25% spending)
table quintile [iw=pop_wt], stat(mean che_25) nformat(%9.3f) 
* 2.iv. Percent of Households in "Catastrophe" (>40% non-food spending)
table quintile [iw=pop_wt], stat(mean che_40) nformat(%9.3f) 
// (Multiply result by 100 to get percentage)

* 3.i. Percent of Households in "Catastrophe" (>10% spending)
table poor [iw=pop_wt], stat(mean che_10) nformat(%9.3f) 
* 3.ii. Percent of Households in "Catastrophe" (>15% spending)
table poor [iw=pop_wt], stat(mean che_15) nformat(%9.3f) 
* 3.iii. Percent of Households in "Catastrophe" (>25% spending)
table poor [iw=pop_wt], stat(mean che_25) nformat(%9.3f) 
* 2.iv. Percent of Households in "Catastrophe" (>40% non-food spending)
table poor [iw=pop_wt], stat(mean che_40) nformat(%9.3f) 




* 3. Percent of Households utilizing Distress Financing
table quintile [iw=pop_wt], stat(mean distress_hh) nformat(%9.3f)


* Label the dataset so you know what it is later
label data "NLSS-IV Household Financial Protection Indicators (CHE & Distress)"

* Save it to your temporary or processed data folder
save "$data_tmp/health_financial_protection_hh.dta", replace


* --- STEP 1: PREPARE INDIVIDUAL DATA ---
use "$data_raw/S08.dta", clear

merge m:1 psu_number hh_number using "$data_tmp/final_nominal_consumption.dta", keepusing(total_nom_cons)
drop _merge
merge m:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing (psu_number hh_number prov ad_4 prov domain ad_4 poor pcep quintile_pcep hhs_wt ind_wt hhsize)
drop _merge



gen pop_wt = hhs_wt * hhsize

* --- STEP 2: CLEAN DISEASE VARIABLES ---
* In NLSS, usually 1=Yes, 2=No. We need 1=Yes, 0=No for averages.

* A. Chronic Illness (NCDs) - q08_02
* "Do you suffer from a non-communicable illness?"
gen chronic_illness = 0
replace chronic_illness = 1 if q08_02 == 1

* B. Acute Illness (Recent) - q08_10
* "Have you had any health problem... in last 30 days?"
gen acute_illness = 0
replace acute_illness = 1 if q08_10 == 1

* --- STEP 3: GENERATE THE TABLE ---
* We calculate the MEAN (which equals the Percentage when multiplied by 100)
table quintile [iw=pop_wt], stat(mean chronic_illness acute_illness) nformat(%9.3f)

* Save the Individual Disease Data
label data "NLSS-IV Individual Disease Prevalence (Chronic/Acute)"
save "$data_tmp/health_disease_individual.dta", replace















