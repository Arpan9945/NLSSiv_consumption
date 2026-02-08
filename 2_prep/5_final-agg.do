*------------------------------------------------------------------------------*
* STEP 4: FINAL AGGREGATION (MASTER MERGE)                                     *
*------------------------------------------------------------------------------*

* 1. START WITH FOOD AGGREGATE
use "$data_tmp/agg_food_final.dta", clear

* 2. MERGE NON-FOOD (NON-DURABLE)
merge 1:1 psu_number hh_number using "$data_tmp/agg_nonfood_nondurable_final.dta"
drop if _merge == 2 // Should not happen, but safety check
drop _merge
replace agg_nonfood_nondurable = 0 if agg_nonfood_nondurable == .

* 3. MERGE HOUSING (RENT + UTILITIES)
merge 1:1 psu_number hh_number using "$data_tmp/agg_housing_final.dta"
drop if _merge == 2
drop _merge
replace housing_aggregate_annual = 0 if housing_aggregate_annual == .

* 4. MERGE DURABLES FLOW
merge 1:1 psu_number hh_number using "$data_tmp/agg_durables_final.dta"
drop if _merge == 2
drop _merge
replace durables_flow_annual = 0 if durables_flow_annual == .

* 5. MERGE POVERTY LINE & HH SIZE (FROM OFFICIAL FILE)
* We need hhsize to calculate Per Capita, and the official weights.
merge 1:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing(hhsize hhs_wt pline domain ad_4 paasche)
keep if _merge == 3
drop _merge

*------------------------------------------------------------------------------*
* STEP 5: CALCULATE TOTAL CONSUMPTION (NOMINAL)                                *
*------------------------------------------------------------------------------*

* Total Nominal Household Consumption
gen total_consumption_nominal = food_aggregate_annual + ///
                                agg_nonfood_nondurable + ///
                                housing_aggregate_annual + ///
                                durables_flow_annual

label var total_consumption_nominal "Total Annual Nominal HH Consumption"

*------------------------------------------------------------------------------*
* STEP 6: CALCULATE PER CAPITA CONSUMPTION (PCEP)                              *
*------------------------------------------------------------------------------*

* Nominal Per Capita Consumption (NPR per person per year)
gen pcep_nominal = total_consumption_nominal / hhsize
label var pcep_nominal "Per Capita Nominal Consumption"



* Save Final Analytical File
save "$data_tmp/final_consumption_aggregate.dta", replace