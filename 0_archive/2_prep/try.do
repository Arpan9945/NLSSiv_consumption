* Define Paths
global raw_path "C:\Users\Arpan Acharya\OneDrive - HERD\Documents\Personal\CIH-project\1_raw"
global temp_path "C:\Users\Arpan Acharya\OneDrive - HERD\Documents\Personal\CIH-project\2_temp"

* --- 1. Load Food Data ---
use "$raw_path\S05.dta", clear

* --- 2. Clean Data (Zeros instead of dots) ---
foreach var in q05_03 q05_03_b q05_04 q05_04_b q05_05 q05_05_b {
    capture replace `var' = 0 if `var' == .
}

* --- 3. Calculate Market Unit Values (Prices) ---
* Unit Value = Market Value (q05_04_b) / Market Quantity (q05_04)
gen uv_market = q05_04_b / q05_04 if q05_04 > 0 & q05_04_b > 0

* --- 4. Calculate Median Price per Item ---
* We use the median of the calculated market prices to value home production.
bysort food_code: egen median_price = median(uv_market)

* Fallback: If no median (e.g., rarely bought items), use the mean.
bysort food_code: egen mean_price = mean(uv_market)
replace median_price = mean_price if median_price == .

* If still missing (no one bought it ever), use a proxy price of 1 to avoid zeroing out consumption (rare case)
replace median_price = 1 if median_price == .

* --- 5. Re-Value Consumption (The Methodology Fix) ---

* A. Market Purchases (Use self-reported value mostly)
gen val_market = q05_04_b
* Correction: If they bought it but value is missing, use Qty * Median Price
replace val_market = q05_04 * median_price if (val_market == 0 | val_market == .) & q05_04 > 0

* B. Home Production (Use Quantity * Median Price)
* Methodology: "Estimate imputed item expenditures... by multiplying quantity by median unit values."
gen val_home = q05_03 * median_price

* C. In-Kind (Use Quantity * Median Price)
gen val_inkind = q05_05 * median_price

* --- 6. Annualize (365/7) ---
gen weekly_total = val_market + val_home + val_inkind
gen agg_food_annual = weekly_total * (365/7)

* --- 7. Collapse to Household Level ---
bysort psu_number hh_number: egen hh_food_total = total(agg_food_annual)
bysort psu_number hh_number: keep if _n == 1

* Keep and Save
keep psu_number hh_number hh_food_total
label var hh_food_total "Annual Food (Excluding Eating Out)"
save "$temp_path\temp_food_main.dta", replace

display "Main Food Aggregate (Methodology Applied) Complete."








* --- Load Section 6A ---
use "$raw_path\S06A.dta", clear

* 1. Clean Missing Values (Treat dots as zero)
replace q06_02a_a = 0 if q06_02a_a == .
replace q06_02a_b = 0 if q06_02a_b == .

* ---------------------------------------------------------
* IMPORTANT: IDENTIFY EXCLUSIONS
* ---------------------------------------------------------
* The Methodology (Box 1) says we MUST exclude:
* - Health expenses
* - Taxes, Fines
* - Marriages, Funerals, Dowries
* - Remittances sent
* - Construction/Major Repairs
* - Firewood (Box 2 says exclude from utilities if captured elsewhere)
*
* Run this line to see the list, then fill in the "DROP" command below:

* ---------------------------------------------------------

* <--- PASTE YOUR EXCLUSIONS HERE IN THE NEXT STEP --->
* Example: drop if s06a_code >= 500 & s06a_code <= 520
* For now, I will comment this out until you give me the codes.
* drop if s06a_code == ...


* --- 2. CALCULATE ANNUALIZED 30-DAY SPENDING ---
gen annual_30_day = q06_02a_b * 12

* --- 3. CLASSIFY ITEMS (Regular vs. Irregular) ---
* Methodology: "Item is regular if annualized 30-day median is within 20% of 12-month median"

* Calculate Medians by Item (National Level)
bysort s06a_code: egen med_30 = median(annual_30_day)
bysort s06a_code: egen med_12 = median(q06_02a_a)

* Calculate Ratio
gen ratio = med_30 / med_12

* Define Regular (1) vs Irregular (0)
* (If ratio is between 0.8 and 1.2, it is Regular)
gen is_regular = 0
replace is_regular = 1 if ratio >= 0.8 & ratio <= 1.2

* --- 4. ASSIGN FINAL EXPENDITURE ---
gen final_item_cost = 0

* A. REGULAR ITEMS: Use 30-day * 12
replace final_item_cost = annual_30_day if is_regular == 1
* (Fallback: If 30-day is missing/zero but they have 12-month data, use that)
replace final_item_cost = q06_02a_a if is_regular == 1 & final_item_cost == 0

* B. IRREGULAR ITEMS: Use 12-month
replace final_item_cost = q06_02a_a if is_regular == 0
* (Fallback: If 12-month is missing/zero but they have 30-day data, use that)
replace final_item_cost = annual_30_day if is_regular == 0 & final_item_cost == 0

* --- 5. AGGREGATE TO HOUSEHOLD ---
collapse (sum) nonfood_nondurable = final_item_cost, by(psu_number hh_number)

label var nonfood_nondurable "Annual Non-Food Non-Durable (S06A)"
save "$temp_path\temp_nonfood_nondurable.dta", replace

display "Section 6A Complete. PLEASE CHECK EXCLUSIONS!"



* --- Load Data ---
use "$raw_path\S06A.dta", clear

* 1. Handle Missing Values
replace q06_02a_a = 0 if q06_02a_a == .
replace q06_02a_b = 0 if q06_02a_b == .




*************88888





********************8


* Stuck here


* --- Load Data ---
use "$raw_path\S06A.dta", clear

* 1. Handle Missing Values
replace q06_02a_a = 0 if q06_02a_a == .
replace q06_02a_b = 0 if q06_02a_b == .

* 2. Prepare Item Name for Filtering
* (We use the existing string variable 's06a_desc')
gen item_name = upper(s06a_desc) 

* ---------------------------------------------------------
* 3. APPLY EXCLUSIONS (Methodology Box 1 & Box 3)
* ---------------------------------------------------------
* IMPORTANT: We match text patterns. 

* A. Exclude HEALTH (Box 1.1)
* Drops: Doctor fees, medicines, hospital admission
drop if regexm(item_name, "HEALTH") | regexm(item_name, "TREATMENT") | regexm(item_name, "PREVENTIVE") | regexm(item_name, "DOCTOR") | regexm(item_name, "MEDICINE") | regexm(item_name, "HOSPITAL")

* B. Exclude TAXES, FINES, LEGAL (Box 1.6)
* Drops: Lawyer fees, fines, registration fees, taxes
drop if regexm(item_name, "TAX") | regexm(item_name, "LEGAL") | regexm(item_name, "ADMINISTRATIVE") | regexm(item_name, "REGISTRATION") | regexm(item_name, "FINE") | regexm(item_name, "LAWYER")

* C. Exclude MARRIAGE, FUNERALS, RELIGIOUS (Box 1.4, 1.3)
* Drops: Marriage costs, donations, religious ceremonies
drop if regexm(item_name, "MARRIAGE") | regexm(item_name, "FUNERAL") | regexm(item_name, "DONATION") | regexm(item_name, "CEREMONY") | regexm(item_name, "SOCIAL SECURITY") | regexm(item_name, "RELIGIOUS")

* D. Exclude INSURANCE & FINANCIAL SERVICES (Box 1.5)
* Drops: Life insurance, banking fees
drop if regexm(item_name, "INSURANCE") | regexm(item_name, "PREMIUM") | regexm(item_name, "BANKING") | regexm(item_name, "INTEREST") | regexm(item_name, "LOAN")

* E. Exclude EDUCATION (Temporarily - Calculated in Step 2)
* Drops: Tuition, books, uniforms, admission fees
drop if regexm(item_name, "EDUCATION") | regexm(item_name, "SCHOOL") | regexm(item_name, "COLLEGE") | regexm(item_name, "TUITION") | regexm(item_name, "BOOKS") | regexm(item_name, "STATIONERY") | regexm(item_name, "UNIFORM") | regexm(item_name, "ADMISSION")

* F. Exclude PURCHASE OF MAJOR DURABLES (Box 3)
* We exclude BIG ASSETS (Vehicles, Land, House, Large Appliances).
* We KEEP small semi-durables (Pots, pans, bags, small tools).
drop if regexm(item_name, "PURCHASE OF CAR") | regexm(item_name, "PURCHASE OF JEEP") | regexm(item_name, "PURCHASE OF MOTORCYCLE") | regexm(item_name, "PURCHASE OF SCOOTER") 
drop if regexm(item_name, "PURCHASE OF HOUSE") | regexm(item_name, "PURCHASE OF LAND") | regexm(item_name, "CONSTRUCTION")
drop if regexm(item_name, "PURCHASE OF GOLD") | regexm(item_name, "JEWELLERY")
drop if regexm(item_name, "PURCHASE OF REFRIGERATOR") | regexm(item_name, "PURCHASE OF WASHING MACHINE")
* (Note: Furniture is borderline. Usually major furniture is excluded from annual consumption, but minor repairs are kept. I will exclude major furniture purchase based on standard LSMS rules).
drop if regexm(item_name, "PURCHASE OF BED") | regexm(item_name, "PURCHASE OF SOFA") | regexm(item_name, "FURNITURE")

* ---------------------------------------------------------
* 4. CLASSIFY: REGULAR VS IRREGULAR (Methodology 3.2.1)
* ---------------------------------------------------------

* A. Annualize 30-Day Spending
gen annual_30_day = q06_02a_b * 12

* B. Calculate National Medians
* Use s06a_code (which is numeric) for sorting/grouping
bysort s06a_code: egen med_30 = median(annual_30_day)
bysort s06a_code: egen med_12 = median(q06_02a_a)

* C. The "20% Rule"
* Regular if annualized 30-day median is within 20% of 12-month median
gen ratio = med_30 / med_12
gen is_regular = 0
* Avoid division by zero issues
replace ratio = 0 if med_12 == 0
replace is_regular = 1 if ratio >= 0.8 & ratio <= 1.2 & ratio != 0

* ---------------------------------------------------------
* 5. CALCULATE FINAL COST
* ---------------------------------------------------------
gen item_cost = 0

* A. Regular Items: Priority is 30-day recall
replace item_cost = annual_30_day if is_regular == 1
* Fallback: If 30-day is 0/missing but 12-month exists, use 12-month
replace item_cost = q06_02a_a if is_regular == 1 & (item_cost == 0 | item_cost == .)

* B. Irregular Items: Priority is 12-month recall
replace item_cost = q06_02a_a if is_regular == 0
* Fallback: If 12-month is 0/missing but 30-day exists, use 30-day annualized
replace item_cost = annual_30_day if is_regular == 0 & (item_cost == 0 | item_cost == .)

* ---------------------------------------------------------
* 6. AGGREGATE GENERAL NON-FOOD
* ---------------------------------------------------------
collapse (sum) nonfood_general = item_cost, by(psu_number hh_number)
label var nonfood_general "General Non-Food (Excl. Edu/Rent/Health)"
save "$temp_path\temp_nonfood_general.dta", replace

display "General Non-Food Calculated Successfully (Exclusions Applied)."
































* --- Step 2A: Education from S06A ---
use "$raw_path\S06A.dta", clear

* 1. Handle Missing Values
replace q06_02a_a = 0 if q06_02a_a == .

* 2. Identify Education Items (Same regex as before, but we KEEP them)
gen item_name = upper(s06a_desc) 

keep if regexm(item_name, "EDUCATION") | regexm(item_name, "SCHOOL") | regexm(item_name, "COLLEGE") | regexm(item_name, "TUITION") | regexm(item_name, "BOOKS") | regexm(item_name, "STATIONERY") | regexm(item_name, "UNIFORM") | regexm(item_name, "ADMISSION")

* 3. Aggregate to Household Level
* (Education is usually an annual expense, so we rely on the 12-month recall: q06_02a_a)
collapse (sum) educ_s06 = q06_02a_a, by(psu_number hh_number)

label var educ_s06 "Education Cost (from S06 Household Recall)"
save "$temp_path\temp_educ_s06.dta", replace



describe using "$raw_path\S07.dta"







* =========================================================
* STEP 2: CALCULATE EDUCATION EXPENSES (MAX RULE)
* =========================================================

* ---------------------------------------------------------
* PART A: Calculate from Section 6A (Household Level)
* ---------------------------------------------------------
use "$raw_path\S06A.dta", clear

* 1. Clean Missing Values
replace q06_02a_a = 0 if q06_02a_a == .

* 2. Identify Education Items (The same text patterns we excluded earlier)
gen item_name = upper(s06a_desc)
keep if regexm(item_name, "EDUCATION") | regexm(item_name, "SCHOOL") | regexm(item_name, "COLLEGE") | regexm(item_name, "TUITION") | regexm(item_name, "BOOKS") | regexm(item_name, "STATIONERY") | regexm(item_name, "UNIFORM") | regexm(item_name, "ADMISSION")

* 3. Collapse to Household Level
* Note: Education is an annual expense, so we use the 12-month recall (q06_02a_a)
collapse (sum) educ_s06 = q06_02a_a, by(psu_number hh_number)

label var educ_s06 "Education Cost (S06 Household Recall)"
save "$temp_path\temp_educ_s06.dta", replace


* ---------------------------------------------------------
* PART B: Calculate from Section 7 (Individual Level)
* ---------------------------------------------------------
use "$raw_path\S07.dta", clear

* 1. Clean Missing Values for Expense Variables (A to F)
local educ_vars q07_17_a q07_17_b q07_17_c q07_17_d q07_17_e q07_17_f
foreach var of local educ_vars {
    replace `var' = 0 if `var' == .
}

* 2. Calculate Total Education Cost per Person
* We EXCLUDE q07_17_g (Snacks) to avoid double counting with Food Consumption.
gen member_educ_expense = q07_17_a + q07_17_b + q07_17_c + q07_17_d + q07_17_e + q07_17_f

* 3. Collapse to Household Level
collapse (sum) educ_s07 = member_educ_expense, by(psu_number hh_number)

label var educ_s07 "Education Cost (S07 Individual Sum)"
save "$temp_path\temp_educ_s07.dta", replace


* ---------------------------------------------------------
* PART C: MERGE AND APPLY MAX RULE
* ---------------------------------------------------------
use "$temp_path\temp_educ_s06.dta", clear

* Merge with S07 data
merge 1:1 psu_number hh_number using "$temp_path\temp_educ_s07.dta"
drop _merge

* Handle missing values after merge (if a HH reported in one section but not the other)
replace educ_s06 = 0 if educ_s06 == .
replace educ_s07 = 0 if educ_s07 == .

* Apply the "Max Value" Rule
gen educ_final = max(educ_s06, educ_s07)

label var educ_final "Final Education Consumption (Max of S06/S07)"

* Save final Education component
keep psu_number hh_number educ_final
save "$temp_path\comp_education.dta", replace

display "Step 2 Complete: Education Expenses Calculated."


























* =========================================================
* STEP 3 & 4: HOUSING AND UTILITIES
* =========================================================
use "$raw_path\S02.dta", clear

* ---------------------------------------------------------
* 1. Clean Missing Values (Set . to 0 for calculations)
* ---------------------------------------------------------
local vars q02_13 q02_18 q02_17 q02_23 q02_26 q02_30 q02_31_a2 q02_31_b2 q02_31_c2
foreach v of local vars {
    capture confirm variable `v' // Check if variable exists
    if _rc == 0 {
        replace `v' = 0 if `v' == .
    }
}

* Clean Firewood variables separately
local fire_vars q02_35_1a q02_35_2a q02_35_3a q02_35_4a q02_35_5a
foreach v of local fire_vars {
    replace `v' = 0 if `v' == .
}

* ---------------------------------------------------------
* 2. CALCULATE HOUSING CONSUMPTION (Rent/Imputed Rent)
* ---------------------------------------------------------
gen housing_annual = 0

* A. Owners (q02_11 == 1 means Yes)
* Use q02_13: Estimated potential monthly rent
replace housing_annual = q02_13 * 12 if q02_11 == 1

* B. Renters (Check q02_16 - usually codes 1-5, assume 'Renter' exists)
* Use q02_18: Actual monthly rent paid
* Note: We prioritize actual rent paid if they are renters
replace housing_annual = q02_18 * 12 if q02_18 > 0 & housing_annual == 0

* C. Others (Squatters / Provided Free)
* Use q02_17: Estimated potential monthly rent
replace housing_annual = q02_17 * 12 if housing_annual == 0 & q02_17 > 0

label var housing_annual "Annual Housing Consumption (Actual or Imputed)"


* ---------------------------------------------------------
* 3. CALCULATE UTILITIES CONSUMPTION
* ---------------------------------------------------------
gen util_water = q02_23
gen util_garbage = q02_26 * 12  // q02_26 is monthly
gen util_elec = q02_30

* Communication (Phone/Cable/Internet)
gen util_comm = q02_31_a2 + q02_31_b2 + q02_31_c2

* Firewood / Cooking Fuel
gen util_fuel = q02_35_1a + q02_35_2a + q02_35_3a + q02_35_4a + q02_35_5a

* Total Utilities
gen utilities_total = util_water + util_garbage + util_elec + util_comm + util_fuel
label var utilities_total "Annual Utilities (Water, Elec, Comm, Fuel)"

* ---------------------------------------------------------
* 4. SAVE COMPONENTS
* ---------------------------------------------------------
keep psu_number hh_number housing_annual utilities_total

save "$temp_path\comp_housing_utils.dta", replace

display "Step 3 & 4 Complete: Housing and Utilities Calculated."





























* =========================================================
* FINAL STEP: MERGE ALL NON-FOOD COMPONENTS
* =========================================================

* 1. Start with General Non-Food (Step 1)
use "$temp_path\temp_nonfood_general.dta", clear

* 2. Merge Education (Step 2)
merge 1:1 psu_number hh_number using "$temp_path\comp_education.dta"
drop _merge
* Replace missing with 0 (for HHs with no education spend)
replace educ_final = 0 if educ_final == .

* 3. Merge Housing & Utilities (Step 3 & 4)
merge 1:1 psu_number hh_number using "$temp_path\comp_housing_utils.dta"
drop _merge
* Replace missing with 0
replace housing_annual = 0 if housing_annual == .
replace utilities_total = 0 if utilities_total == .

* ---------------------------------------------------------
* 4. CALCULATE TOTAL NON-FOOD CONSUMPTION
* ---------------------------------------------------------
gen total_nonfood_annual = nonfood_general + educ_final + housing_annual + utilities_total

label var total_nonfood_annual "Total Annual Non-Food Consumption (Nominal)"

* 5. Sanity Check (Inspect the means)
summarize nonfood_general educ_final housing_annual utilities_total total_nonfood_annual, detail

* 6. Save Final Non-Food Aggregate
save "$temp_path\final_nonfood_aggregate.dta", replace

display "SUCCESS: Final Non-Food Aggregate Created!"




















* =========================================================
* RE-RUN STEP 5B: MAIN FOOD CONSUMPTION (Ensure Collapse)
* =========================================================
use "$raw_path\S05.dta", clear

* 1. Clean Missing Values for VALUES (Rupees)
* q05_03_b = Value of Home Production
* q05_04_b = Value of Purchases
* q05_05_b = Value of In-Kind
local value_vars q05_03_b q05_04_b q05_05_b
foreach var of local value_vars {
    capture confirm variable `var' 
    if _rc == 0 {
        replace `var' = 0 if `var' == .
    }
}

* 2. Calculate Total Value per Item (7-day recall)
gen item_value_7day = q05_03_b + q05_04_b + q05_05_b

* 3. COLLAPSE to Household Level (Crucial Step)
collapse (sum) food_main_7day = item_value_7day, by(psu_number hh_number)

label var food_main_7day "Main Food Consumption (7-day Recall)"

* 4. Save the file immediately
save "$temp_path\temp_food_main.dta", replace


* =========================================================
* RE-RUN STEP 5C: MERGE AND ANNUALIZE
* =========================================================
use "$temp_path\temp_food_main.dta", clear

* 1. Merge with Food Away from Home (S05B)
merge 1:1 psu_number hh_number using "$temp_path\temp_food_away.dta"
drop _merge

* 2. Handle Households with missing Food Away data
replace food_away_7day = 0 if food_away_7day == .

* 3. Calculate Total 7-Day Food Consumption
* (Now food_main_7day is guaranteed to exist)
gen food_total_7day = food_main_7day + food_away_7day

* 4. Annualize (365 days / 7 days)
gen food_annual_nominal = food_total_7day * (365/7)

label var food_annual_nominal "Total Annual Food Consumption (Nominal)"
save "$temp_path\final_food_aggregate.dta", replace

display "SUCCESS: Food Aggregate Calculated!"
















* =========================================================
* STEP 6: TOTAL AGGREGATE & PER CAPITA CONSUMPTION
* =========================================================

* ---------------------------------------------------------
* 1. Calculate Household Size (from Roster S01)
* ---------------------------------------------------------
use "$raw_path\S01.dta", clear

* Create a counter for each member
gen member_count = 1

* Collapse to get total members per household
collapse (sum) hh_size = member_count, by(psu_number hh_number)

label var hh_size "Household Size"
save "$temp_path\hh_size.dta", replace

* ---------------------------------------------------------
* 2. Merge Everything Together
* ---------------------------------------------------------
* Start with Non-Food
use "$temp_path\final_nonfood_aggregate.dta", clear

* Merge Food
merge 1:1 psu_number hh_number using "$temp_path\final_food_aggregate.dta"
drop _merge

* Merge Household Size
merge 1:1 psu_number hh_number using "$temp_path\hh_size.dta"
keep if _merge == 3  // Keep only valid households
drop _merge

* ---------------------------------------------------------
* 3. Calculate Totals and Per Capita
* ---------------------------------------------------------
* Replace missing values with 0 (just in case)
replace total_nonfood_annual = 0 if total_nonfood_annual == .
replace food_annual_nominal = 0 if food_annual_nominal == .

* TOTAL HOUSEHOLD CONSUMPTION (Nominal)
gen total_consumption_annual = total_nonfood_annual + food_annual_nominal
label var total_consumption_annual "Total Annual Household Consumption (Nominal)"

* PER CAPITA CONSUMPTION (Nominal)
gen pcc_nominal = total_consumption_annual / hh_size
label var pcc_nominal "Per Capita Consumption (Nominal)"

* ---------------------------------------------------------
* 4. Inspect the Results
* ---------------------------------------------------------
* This is the most important check.
summarize pcc_nominal, detail

save "$temp_path\FINAL_CONSUMPTION_NOMINAL.dta", replace

display "----------------------------------------------------"
display "SUCCESS: Nominal Consumption Aggregate Created!"
display "----------------------------------------------------"