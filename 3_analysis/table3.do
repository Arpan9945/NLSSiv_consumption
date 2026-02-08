*------------------------------------------------------------------------------*
* STEP 8 (ADDENDUM): URBAN / RURAL (3 GROUPS)                                  *
*------------------------------------------------------------------------------*

use "$data_tmp/final_nominal_consumption.dta", clear

* Ensure we are using ad_4 which typically holds:
* 1 = Kathmandu Valley Urban
* 2 = Other Urban
* 3 = Rural

* Check if ad_4 is labeled, if not, label it manually for the table
label define ad4_lab 1 "Kathmandu Valley (Urban)" 2 "Other Urban" 3 "Rural", modify
label values ad_4 ad4_lab

* Decode to string for the 'Category' column
decode ad_4, gen(Category)

* Collapse to calculate means
collapse (mean) total_nom_cons share_food share_housing share_educ share_other [aw=hhs_wt], by(Category)

* Assign SortOrder
* 1=National, 2=Province, 3=Analytical Domain. We set this to 4 to put it at the bottom.
gen SortOrder = 4

* Append to the Master Table
append using "Table_11_2_Final.dta"
save "Table_11_2_Final.dta", replace

*------------------------------------------------------------------------------*
* STEP 9: FINAL EXPORT TO EXCEL                                                *
*------------------------------------------------------------------------------*
use "Table_11_2_Final.dta", clear

* Sort so it appears in order: National -> Province -> Domain -> Urban/Rural (3 Groups)
sort SortOrder Category

* Formatting Numbers
format total_nom_cons %12.0fc
format share_* %9.1f

* Rename Variables to match the Table Headers
rename total_nom_cons Avg_HH_Consumption_NPR
rename share_food     Share_Food
rename share_housing  Share_Rent_Utils
rename share_educ     Share_Education
rename share_other    Share_Other_NonFood

* Export
export excel using "3_analysis/Table_11_3_Nominal_Shares.xlsx", firstrow(variables) replace

display "----------------------------------------------------------------"
display "SUCCESS: Table 11.2 saved with 3 Urban/Rural groups."
display "----------------------------------------------------------------"