/* PROGRAM DESCRIPTION
program: cr_SNAP_county_clean_4largest.do
task: cleans SNAP data at the county level for CA, IL, TX & FL

organization:
		0 : setup tasks like directory structure, input & output file names, other useful locals
		1 : Import SNAP datasets and clean
		2 : Merge Census data
		3 : Merge data on undocumented population
		
	 
*/
/* *********************************************************************
	PART 0: PREAMBLE
********************************************************************* */

* 0.1: PREFERENCES
clear all
set more off
set varabbrev on

* 0.2: DIRECTORIES
global base_dir_ari 		"/Users/ariadna/Box Sync/public charge blog/data/" 
global base_dir_aridesk 	"/Users/ariadnavargas/Box Sync/public charge blog/data/" 

cd "${base_dir_aridesk}"

* 0.3: FILE NAMES

* INPUTS
global read					"raw/snap_df_"
global read_cen				"raw/census_county.csv"
global read_mig				"raw/State-County-Unauthorized-Estimates-2016.xlsx"
global read_hisp			"raw/all-counties_14.xlsx"

* OUTPUTS
global save				"clean/SNAP_county_clean.dta"
global save_st			"clean/SNAP_state_clean"
global save_4st			"clean/SNAP_county_clean_4st"
global save_IL			"clean/SNAP_county_clean_IL"
global save_FL			"clean/SNAP_county_clean_FL"
global save_TX			"clean/SNAP_county_clean_TX"
global save_CA			"clean/SNAP_county_clean_CA"
global save_reg			"stats/reg_SNAP_county"

/****************************************
 1. Import SNAP datasets and clean
****************************************/

import delimited "${read}0115.csv", varnames(1) encoding(ISO-8859-1)clear
collapse (sum) calcsnaptotalpaandnonpapeople, by(county_state county_id state_id stateabbrev)
tostring county_id, format(%03.0f) replace
tostring state_id, format(%02.0f) replace
tostring county_state, format(%05.0f) replace
drop if county_id=="000" | stateabbrev=="Summary"  | stateabbrev==""
rename calcsnaptotalpaandnonpapeople snap_beneficiaries_0115
bysort stateabbrev: gen states_freq=_N
save "${save}", replace

foreach mnth in "0715" "0116" "0716" ///
"0117" "0717" "0118" "0718" "0119" {
	import delimited "${read}`mnth'.csv", varnames(1) encoding(ISO-8859-1)clear
	collapse (sum) calcsnaptotalpaandnonpapeople, by(county_state county_id state_id stateabbrev)
	rename calcsnaptotalpaandnonpapeople snap_beneficiaries_`mnth'
	tostring county_id, format(%03.0f) replace
	tostring state_id, format(%02.0f) replace
	tostring county_state, format(%05.0f) replace
	drop if county_id=="000" | stateabbrev=="Summary"  | stateabbrev==""
	bysort stateabbrev: gen states_freq=_N
	merge 1:1 county_state using "${save}"
	tab _merge
	drop _merge
	save "${save}", replace
}


// Calculate biannual change in SNAP enrollment

forval x = 15/18 {
	gen snap_change_07`x' = ((snap_beneficiaries_07`x'/snap_beneficiaries_01`x')-1)*100
	local y=`x'+1
	gen snap_change_01`y' = ((snap_beneficiaries_01`y'/snap_beneficiaries_07`x')-1)*100
}




// Keep only: CA, TX, FL & IL 
// Note: NY doesn't report info by county and IL only has info for 77 counties (out of 102)

//
// keep if state_abbrev=="CA" | state_abbrev=="IL" | ///
// state_abbrev=="FL"  | state_abbrev=="NY"  | state_abbrev=="TX"

preserve
keep snap_change_* stateabbrev county_state
reshape long snap_change_, i(stateabbrev  county_state) j(semester) string
rename snap_change_ snap_biannual_chan
label var snap_biannual_chan "SNAP beneficiaries-biannual change(%)"
save "${save}",replace
restore

drop snap_change_* 
reshape long snap_beneficiaries_, i(stateabbrev county_id state_id county_state) j(semester) string

merge 1:1 county_state semester using "${save}"
drop _merge

rename snap_beneficiaries_ snap_beneficiaries
label var snap_beneficiaries "SNAP beneficiaries"
label var state_id "State FIPS code"
label var county_id "County FIPS code"
rename county_state county_state_id
label var county_state_id "County-State FIPS code"
rename stateabbrev state_abbrev
label var state_abbrev "State name abbreviation"
drop states_freq


save "${save}", replace

gen sem=semester=="0115"
replace sem=2 if semester=="0715"
replace sem=3 if semester=="0116"
replace sem=4 if semester=="0716"
replace sem=5 if semester=="0117"
replace sem=6 if semester=="0717"
replace sem=7 if semester=="0118"
replace sem=8 if semester=="0718"
replace sem=9 if semester=="0119"

label define seme 1 "Jan15" 2 "Jul15" 3 "Jan16" 4 "Jul16" ///
5 "Jan17" 6 "Jul17" 7 "Jan18" 8 "Jul18" 9 "Jan19"
label val sem seme
label var sem "Semester" // mmyy format
label var semester "Semester" // number of semester
save "${save}", replace

gen year=2015 if semester=="0115" | semester=="0715"
replace year=2016 if semester=="0116" | semester=="0716"
replace year=2017 if semester=="0117" | semester=="0717"
replace year=2018 if semester=="0118" | semester=="0718"
replace year=2019 if semester=="0119" | semester=="0719"

gen month=1 if semester== "0115" | semester== "0116" | semester== "0117" | semester== "0118" | semester== "0119"
replace month=7 if semester== "0715" | semester== "0716" | semester== "0717" | semester== "0718"

gen date = ym(year,month)
format date %tmMCY

keep if state_abbrev=="CA" | state_abbrev=="IL" | ///
state_abbrev=="FL"  | state_abbrev=="NY"  | state_abbrev=="TX"

/****************************************
 2. Merge Census data
****************************************/

import delimited "${read_cen}", varnames(1) encoding(ISO-8859-1)clear
// keep if state_name==" California"  | state_name==" Illinois" | ///
// state_name==" Florida" | state_name==" Texas"
rename county county_id
rename state state_id

tostring county_id, format(%03.0f) replace
tostring state_id, format(%02.0f) replace

split state_name, parse(" ")
drop state_name
rename state_name1 state_name
replace state_name=state_name + " " + state_name2 if  state_name2!=""
replace state_name=state_name + " " + state_name3 if  state_name3!=""
drop state_name2 state_name3

rename population pop_co
label var pop_ "Total population - co"

preserve
collapse (sum) pop_co, by(state_id)
rename pop_co pop_st
label var pop_st "Total population - st"
tempfile popst
save `popst',replace
restore

merge m:1 state_id using `popst'
tab _merge
drop _merge 

merge 1:m county_id state_id using "${save}"

// drop if _merge!=3
drop _merge v1
save "${save}", replace

/****************************************
 3. Merge data on undocumented population
****************************************/

// 3.1 Undocumented population at the county level

import excel "${read_mig}", sheet("U.S. and Counties") cellrange(A4:C197) firstrow clear
// split County, parse("County")
rename County county_name
// drop County
// keep if State=="California" | State=="Florida" | ///
// State=="Texas" | State=="Illinois"
rename TotalUn pop_un_co
label var pop_un_co "Unauthorized population - co"
rename State state_name

merge 1:m state_name county_name using "${save}"
// drop if _merge==2
drop _merge

/*
      joined counties in undocumented migration dataset
	  +---------------------------------------------------------------+
      |                                      county_name   state_name |
      |---------------------------------------------------------------|
  11. |                     Monterey-San Benito Counties   California |
  29. |                             Sutter-Yuba Counties   California |
  39. |                       Miami-Dade-Monroe Counties      Florida |
  52. | Austin-Matagorda-Waller-Warton-Colorado Counties        Texas |
      +---------------------------------------------------------------+
*/

gen pop_un_co_per = 100*(pop_un_co / pop_co)
label var pop_un_co_per "Undocumented population - county (%)" 
save "${save}", replace

// 3.2 Undocumented population at the state level

import excel "${read_mig}", sheet("U.S. and States") cellrange(A4:B54) firstrow clear

split State, parse(" ")

gen state_name=State1 
replace state_name=state_name + " " + State2 if  State2!=""
replace state_name=state_name + " " + State3 if  State3!=""
drop State*

rename TotalUn pop_un_st
label var pop_un_st "Unauthorized population - st"
drop if state_name=="United States"

merge 1:m state_name using "${save}"

/* we don't have these 10 states:
//       +----------------------+
//       |           state_name |
//       |----------------------|
//    2. |               Alaska |
//    9. | District of Columbia |
//   16. |                 Iowa |
//   20. |                Maine |
//   25. |          Mississippi |
//       |----------------------|
//   27. |              Montana |
//   30. |        New Hampshire |
//   41. |         South Dakota |
//   47. |        West Virginia |
//   49. |              Wyoming |
//       +----------------------+
*/

// drop if _merge==1
drop _merge

gen pop_un_st_per= 100*(pop_un_st/pop_st)

gen year=2015 if semester=="0115" | semester=="0715"
replace year=2016 if semester=="0116" | semester=="0716"
replace year=2017 if semester=="0117" | semester=="0717"
replace year=2018 if semester=="0118" | semester=="0718"
replace year=2019 if semester=="0119" | semester=="0719"

gen month=1 if semester== "0115" | semester== "0116" | semester== "0117" | semester== "0118" | semester== "0119"
replace month=7 if semester== "0715" | semester== "0716" | semester== "0717" | semester== "0718"

gen date = ym(year,month)
format date %tmMCY

save "${save}", replace

// /****************************************
//  4. Save different datasets
// ****************************************/

import excel "${read_hisp}", sheet("County Data 2014") cellrange(A2:AQ3149) firstrow clear
keep if FIPS!=""

rename FIPS county_state_id
rename  AA pop_hispan_prop
label var pop_hispan_prop "Hispanic population(%)"
keep county_state_id pop_
destring pop_hisp, replace force

merge 1:m county_state_id using "${save}"
drop if _merge==1
drop _merge
save "${save}", replace

/****************************************
 5. Save different datasets
****************************************/

// 5.1 State level for all states

preserve
bysort state_name: gen n=_n
keep if n==1 
keep if state_name!=""
keep state_name pop_un_st pop_st state_abbrev semester sem pop_un_st_per
save "${save_st}.dta", replace
export delimited using "${save_st}.csv", replace
restore


// 5.2 County level for 4 states

keep if state_name=="California" | state_name=="Texas"  | ///
state_name=="Florida" | state_name=="Illinois"

save "${save_4st}.dta", replace 
export delimited using "${save_4st}.csv", replace

// 5.3 County level for each state

local states "IL FL CA TX"
foreach st of local states {
	preserve
	keep if state_abbrev=="`st'"
	save "${save_`st'}", replace
	export delimited using "${save_`st'}", replace
	restore
	}

use "${save}", clear
destring county_state_id, replace

collapse (sum) snap_benef, by( date)



xtset date



/****************************************
 6. Reshape and basic stats
****************************************/

keep county_state_id county_name state_name ///
pop_hispan_prop state_id county_id snap_biannual_chan ///
snap_beneficiaries  sem semester

keep if sem!=.
drop sem

rename snap_biannual_chan snap_biannual_chan_ 
rename snap_beneficiaries snap_beneficiaries_

reshape wide snap_biannual_chan snap_beneficiaries, ///
i( county_state_id state_name county_name pop_hispan_prop state_id county_id ) j(semester) string

// gen hispan=1 if pop_hispan_prop>=0
// replace hispan=2 if pop_hispan_prop>=0.01
// replace hispan=3 if pop_hispan_prop>=0.05
// replace hispan=4 if pop_hispan_prop>=0.1
// replace hispan=4 if pop_hispan_prop>0.5
// replace hispan=. if pop_hispan_prop==.



local sem "0715 0116 0716 0117 0717 0118 0718 0119"
foreach x of local sem {
	label var snap_biannual_chan_`x' "SNAP beneficiaries biannual change `x'"
	reg snap_biannual_chan_`x' pop_hispan_prop if ///
	snap_biannual_chan_`x'>-100 & snap_biannual_chan_`x'<100
	est store reg`x'
	}

estout reg* using "${save_reg}.txt" , cells(    b( fmt(%9.2f)  star ) p(fmt(%9.2f) par )  ) starlevels( * 0.10 ** 0.05 *** 0.010) ///
	stats(r2 N, fmt(%11.3f %11.0f) labels("R-squared" "N") ) legend label style(tab) varlabels(_cons Constant) replace 

gen change_0717_0718= 100*((snap_beneficiaries_0718/snap_beneficiaries_0717)-1)
label var change_0717_0718 "SNAP beneficiaries change 07/17-07/18"

scatter snap_biannual_chan_0718 pop_hispan_prop if ( snap_biannual_chan_0718>-10 & snap_biannual_chan_0718<10 )|| /// 
lfit snap_biannual_chan_0718 pop_hispan_prop if (snap_biannual_chan_0718>-10 & snap_biannual_chan_0718<10 )

