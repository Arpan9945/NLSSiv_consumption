* Diagnostic check

*------------------------------------------------------------------------------*
* DIAGNOSTIC: FIND THE VILLAIN ITEM                                            *
*------------------------------------------------------------------------------*
use "$data_raw/S06A.dta", clear

* 1. CHECK DATA TYPE (Vital!)
describe s06a_code

* 2. RE-CALCULATE ANNUAL AMOUNTS
replace q06_02a_b = 0 if q06_02a_b == . 
replace q06_02a_a = 0 if q06_02a_a == . 

* Prioritize "Last 30 Days" x 12, else "Last 12 Months"
gen annualized_amt = q06_02a_b * 12
replace annualized_amt = q06_02a_a if annualized_amt == 0 | annualized_amt == .

* 3. FIND THE HUGE ITEM
* We look for the item that has the Max Value of ~10 Million (2.6m * HH size)
collapse (sum) total_national_exp = annualized_amt (max) max_hh_exp = annualized_amt, by(s06a_code)

* Sort by the Maximum Single Household Expenditure
gsort -max_hh_exp

* List the Top 10 culprits
list s06a_code max_hh_exp total_national_exp in 1/15, sep(0)






summarize pcep_nominal [aw=hhs_wt]
* Generate Per Capita components
gen pcep_food      = food_aggregate_annual / hhsize
gen pcep_nonfood   = agg_nonfood_nondurable / hhsize
gen pcep_housing   = housing_aggregate_annual / hhsize
gen pcep_durables  = durables_flow_annual / hhsize

* Check Weighted Means
display "----------------------------------------------------"
display "WEIGHTED MEANS (COMPARED TO EXPECTATIONS)"
summarize pcep_food [aw=hhs_wt]
summarize pcep_nonfood [aw=hhs_wt]
summarize pcep_housing [aw=hhs_wt]
summarize pcep_durables [aw=hhs_wt]