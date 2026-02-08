*------------------------------------------------------------------------------*
* GENERATE TABLE 11.1 NUMBERS (SIMPLE METHOD)                                  *
*------------------------------------------------------------------------------*
use "$data_raw/poverty.dta", clear


gen pop_wt = hhsize * hhs_wt
svyset psu_number [pw=pop_wt], strata(domain)

tab quintile [iw=pop_wt]

tab prov quintile [iw=pop_wt], row nofreq

tab domain quintile [iw=pop_wt], row nofreq

tab ad_4 quintile [iw = pop_wt], row nofreq


*------------------------------------------------------------------------------*
* GENERATE TABLE 11.4 NUMBERS (SIMPLE METHOD)                                  *
*------------------------------------------------------------------------------*

use "$data_raw/poverty.dta", clear

* 1. CALCULATE FOOD SHARE
* We use the Real (Spatially Adjusted) variables since they matched better.
gen food_share = (pcep_food / pcep) * 100
gen pop_wt = hhs_wt * hhsize
table (prov) (quintile) [iw=pop_wt], statistic(mean food_share) nformat(%9.1f)

svyset psu [pw=hhs_wt], strata(domain)
svy: mean food_share, over(prov quintile_pcep)
svy: mean food_share, over(domain quintile_pcep)

//svyset psu [pw=pop_wt], strata(domain)
//svyset psu [pw=hhs_wt], strata(domain)
//svy: mean food_share, over(prov quintile_pcep)


/*
We don't get the table matching value here because our values are deflated.
We have deflation for food consumption but not for non food share.
*/

gen nom_food_approx = pcep_food * paasche
gen nom_total_approx = pcep * paasche 

* Calculate Share
gen share_approx = (nom_food_approx / nom_total_approx) * 100

* Check Nepal Average
summarize share_approx [aw=pop_wt]


*------------------------------------------------------------------------------*
* GENERATE TABLE 11.6 NUMBERS (SIMPLE METHOD)                                  *
*------------------------------------------------------------------------------*

gen pop_wt = hhsize * hhs_wt

svyset psu [pw=pop_wt], strata(domain)

xtile decile = pcep [pw=hhs_wt], nq(10)
label define dec 1 "D1 (poorest)" 10 "D10 (richest)"
label values decile dec

svy: mean pcep, over(decile)


svyset psu [pw=pop_wt], strata(domain)
svy: mean pcep, over(quintile_pcep)


/*
Using population-weighted survey estimates based on the real per capita expenditure aggregate released with NLSS-IV, mean per capita consumption by quintile closely matches official figures, with minor differences attributable to internal trimming and calibration procedures not replicated in the public-use dataset.
*/


