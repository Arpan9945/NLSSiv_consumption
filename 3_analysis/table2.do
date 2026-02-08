*------------------------------------------------------------------------------*
* STEP 9: FINAL MERGE & TABLE 11.2 GENERATION                                  *
*------------------------------------------------------------------------------*

* 1. LOAD FOOD AGGREGATE
use "$data_tmp/agg_food_final.dta", clear

* 2. MERGE NON-FOOD (Education + Other + Utilities)
merge 1:1 psu_number hh_number using "$data_tmp/agg_nonfood_nondurable_final.dta"
drop if _merge == 2
drop _merge

* 3. MERGE HOUSING (Rent + Utilities)
merge 1:1 psu_number hh_number using "$data_tmp/agg_housing_final.dta"
drop if _merge == 2
drop _merge

* 4. MERGE DURABLES
merge 1:1 psu_number hh_number using "$data_tmp/agg_durables_final.dta"
drop if _merge == 2
drop _merge
replace durables_flow_annual = 0 if durables_flow_annual == .

* 5. MERGE WEIGHTS & DOMAIN INFO
merge 1:1 psu_number hh_number using "$data_raw/poverty.dta", keepusing(hhs_wt domain ad_4 prov hhsize)
keep if _merge == 3
drop _merge

*------------------------------------------------------------------------------*
* 6. DEFINE NOMINAL CONSUMPTION CATEGORIES (AVOID DOUBLE COUNTING)             *
*------------------------------------------------------------------------------*
* A. FOOD
gen nom_food = food_aggregate_annual

* B. HOUSING (Rent + Utilities)
* Housing Aggregate already includes Rent + Water + Elec + Garbage
gen nom_housing = housing_aggregate_annual

* C. EDUCATION
gen nom_educ = educ_final

* D. OTHER NON-FOOD
* CRITICAL: 'agg_nonfood_nondurable' INCLUDED Utilities.
* We must subtract them or use the specific component 'nonfood_s06_other'.
* We use 'nonfood_s06_other' + 'durables_flow_annual'.
gen nom_other = nonfood_s06_other + durables_flow_annual

* TOTAL NOMINAL CONSUMPTION
gen total_nom_cons = nom_food + nom_housing + nom_educ + nom_other

label var total_nom_cons "Total Nominal Household Consumption (Annual)"

*------------------------------------------------------------------------------*
* 7. CALCULATE SHARES (%)                                                      *
*------------------------------------------------------------------------------*
gen share_food    = (nom_food    / total_nom_cons) * 100
gen share_housing = (nom_housing / total_nom_cons) * 100
gen share_educ    = (nom_educ    / total_nom_cons) * 100
gen share_other   = (nom_other   / total_nom_cons) * 100

* Save the Master Analytical File
save "$data_tmp/final_nominal_consumption.dta", replace

*------------------------------------------------------------------------------*
* 8. GENERATE TABLE 11.2 (OUTPUT AGGREGATION)                                  *
*------------------------------------------------------------------------------*

* --- A. NATIONAL (Create the file here) ---
use "$data_tmp/final_nominal_consumption.dta", clear
collapse (mean) total_nom_cons share_food share_housing share_educ share_other [aw=hhs_wt]
gen Category = "National"
gen SortOrder = 1
save "Table_11_2_Final.dta", replace

* --- B. PROVINCE (Append) ---
use "$data_tmp/final_nominal_consumption.dta", clear
collapse (mean) total_nom_cons share_food share_housing share_educ share_other [aw=hhs_wt], by(prov)
decode prov, gen(Category)
drop prov
gen SortOrder = 2
append using "Table_11_2_Final.dta"
save "Table_11_2_Final.dta", replace

* --- C. DOMAIN (Append) ---
use "$data_tmp/final_nominal_consumption.dta", clear
collapse (mean) total_nom_cons share_food share_housing share_educ share_other [aw=hhs_wt], by(domain)
decode domain, gen(Category)
drop domain
gen SortOrder = 3
append using "Table_11_2_Final.dta"
save "Table_11_2_Final.dta", replace

* --- D. URBAN/RURAL (3 Categories) (Append) ---
use "$data_tmp/final_nominal_consumption.dta", clear
* Use ad_4 directly (1=KTM, 2=Other Urban, 3=Rural)
decode ad_4, gen(Category)
collapse (mean) total_nom_cons share_food share_housing share_educ share_other [aw=hhs_wt], by(Category)
gen SortOrder = 4
append using "Table_11_2_Final.dta"
save "Table_11_2_Final.dta", replace

*------------------------------------------------------------------------------*
* 9. FINAL EXPORT TO EXCEL                                                     *
*------------------------------------------------------------------------------*
use "Table_11_2_Final.dta", clear
sort SortOrder Category

* Formatting
format total_nom_cons %12.0fc
format share_* %9.1f

* Rename for Excel Header
rename total_nom_cons Avg_HH_Consumption_NPR
rename share_food     Share_Food
rename share_housing  Share_Housing_Rent_Utils
rename share_educ     Share_Education
rename share_other    Share_Other_NonFood

export excel using "3_analysis/Table_11_2_Nominal_Shares.xlsx", firstrow(variables) replace

display "----------------------------------------------------------------"
display "SUCCESS: Table 11.2 saved as 'Table_11_2_Nominal_Shares.xlsx'"
display "----------------------------------------------------------------"