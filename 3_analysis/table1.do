*------------------------------------------------------------------------------*
* REPLICATE AND EXPORT TABLE 11.1 (WITH 3-CATEGORY URBAN/RURAL)                *
*------------------------------------------------------------------------------*

use "$data_raw/poverty.dta", clear

* 1. DEFINE TEMPFILE
tempfile combined_table
save `combined_table', emptyok

*------------------------------------------------------------------------------*
* SECTION A: NATIONAL (Top Row)
*------------------------------------------------------------------------------*
use "$data_raw/poverty.dta", clear
gen row_label = "National"
gen sort_order = 1

* Collapse to get weighted counts per quintile
collapse (sum) pop_wt = ind_wt, by(row_label quintile_pcep sort_order)

* Calculate Row Percentages
bysort row_label: egen row_total = sum(pop_wt)
gen percent = (pop_wt / row_total) * 100

* Reshape to Wide (Columns 1-5)
keep row_label sort_order quintile_pcep percent
reshape wide percent, i(row_label sort_order) j(quintile_pcep)

save `combined_table', replace

*------------------------------------------------------------------------------*
* SECTION B: PROVINCE (Rows 2-8)
*------------------------------------------------------------------------------*
use "$data_raw/poverty.dta", clear
decode prov, gen(row_label)
gen sort_order = 2

collapse (sum) pop_wt = ind_wt, by(row_label quintile_pcep sort_order)
bysort row_label: egen row_total = sum(pop_wt)
gen percent = (pop_wt / row_total) * 100

keep row_label sort_order quintile_pcep percent
reshape wide percent, i(row_label sort_order) j(quintile_pcep)

append using `combined_table'
save `combined_table', replace

*------------------------------------------------------------------------------*
* SECTION C: ANALYTICAL DOMAINS (Middle Section)
*------------------------------------------------------------------------------*
use "$data_raw/poverty.dta", clear
decode domain, gen(row_label)
gen sort_order = 3

collapse (sum) pop_wt = ind_wt, by(row_label quintile_pcep sort_order)
bysort row_label: egen row_total = sum(pop_wt)
gen percent = (pop_wt / row_total) * 100

keep row_label sort_order quintile_pcep percent
reshape wide percent, i(row_label sort_order) j(quintile_pcep)

append using `combined_table'
save `combined_table', replace

*------------------------------------------------------------------------------*
* SECTION D: URBAN / RURAL (3 CATEGORIES)
*------------------------------------------------------------------------------*
use "$data_raw/poverty.dta", clear

* Use ad_4 directly (1=Kathmandu, 2=Other Urban, 3=Rural)
decode ad_4, gen(row_label)
gen sort_order = 4

collapse (sum) pop_wt = ind_wt, by(row_label quintile_pcep sort_order)
bysort row_label: egen row_total = sum(pop_wt)
gen percent = (pop_wt / row_total) * 100

keep row_label sort_order quintile_pcep percent
reshape wide percent, i(row_label sort_order) j(quintile_pcep)

append using `combined_table'

*------------------------------------------------------------------------------*
* EXPORT TO EXCEL
*------------------------------------------------------------------------------*
sort sort_order row_label

* Rename columns for the Excel header
rename row_label Category
rename percent1 Poorest
rename percent2 Second
rename percent3 Third
rename percent4 Fourth
rename percent5 Richest

* Export
export excel using "3_analysis/Table_11_1_Distribution.xlsx", firstrow(variables) replace

display "SUCCESS! File 'Table_11_1_Distribution.xlsx' created with 3 categories at the bottom."