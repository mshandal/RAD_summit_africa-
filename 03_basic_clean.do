/*

DiCE Survey Data: clean prior to checks
- main survey (Impact Survey) and
- backcheck survey

2020.02.05
*/

*Might need updating if survey changes:
	// local for all section names
	local sections = "consent hh in cr cm fs fl ku kt sv sh"
	
	// local for all calculated vars that should be recoded to numeric
	local destring= "var_unitdayspermo passed flag_educliteracy var_* sv3_unitdays* sv3_totdays* flag_* response1000plusfee"

clear
set more off

*****************************************************************************
***************************** START ********************************

*Monica Shandal 
** adding another change to create a banch 
******************* BASIC CLEAN + RECODE ************************

use "${surveydata_dir}/${surveyname}", clear

/*Append if downloaded non-cumulative data from CTO 
	if $appendto==1 {
		append using "${dice_dir}\06_Data\05_Survey\03_data\02_survey/${appenddate}/Impact Main Survey"
		duplicates drop key, force
	}	*/
	
*Drop system variables
	drop collect* devicephonenum var_avgsurveylength var_surveyreimburse var_consentminseconds testmode m1_agoch m2_agoch m3_agoch phoneok *00

*Recode for ease of creating output
	la var consent "Consent"
	la var phone "phone number" 
	la var cr1_famfrnd "family/friends/neighbours" 
	dec leader, gen(leader_nol)

/*Recode calculated vars which should be numeric
destring passed, replace 
destring var_unitdayspermo, replace
destring flag_educliteracy, replace
destring var_*, replace 
destring flag_*, replace 
destring response1000plusfee, replace*/ 

*REPLACE ABOVE WITH LOOP, didnt work...

foreach v of local destring {
		destring `v', replace
	}
	

*At some point in reassigning teams, fo_name became mismatched with fo, correcting this -
	drop fo_name
	decode fo, gen(fo_name)

******************* DROP DATES OUTSIDE OF SURVEYING PERIOD ************************

*Drop if data collected prior to launch date (2020.02.##)

		//so coded in the above section which creates "attemptdate" from submissiondate	
			
			gen sdate = string(submissiondate, "%tc") if mi(attempt)
			gen sday=substr(sdate,1,2)
			gen smon=substr(sdate,3,3)
			gen syr=substr(sdate,6,4)
			destring sday, replace
			destring syr, replace
			gen smon2=1 if smon=="jan"
			replace smon2=2 if smon=="feb"
			replace smon2=3 if smon=="mar"
			replace smon2=4 if smon=="apr"
			replace smon2=5 if smon=="may"
			replace smon2=6 if smon=="jun"
			replace smon2=7 if smon=="jul"
			replace smon2=8 if smon=="aug"
			replace smon2=9 if smon=="sep"
			replace smon2=10 if smon=="oct"
			replace smon2=11 if smon=="nov"
			replace smon2=12 if smon=="dec"
			drop smon
			ren smon2 smon
		
	split attempt, parse(" ")
	split attempt1, parse("-")
	destring attempt11, gen(yr)
	destring attempt13, gen(day)
	gen mon=.
	replace mon=1 if attempt12=="Jan"
	replace mon=2 if attempt12=="Feb"
	replace mon=3 if attempt12=="Mar"
	replace mon=4 if attempt12=="Apr"
	replace mon=5 if attempt12=="May"
	replace mon=6 if attempt12=="Jun"
	replace mon=7 if attempt12=="Jul"
	replace mon=8 if attempt12=="Aug"
	replace mon=9 if attempt12=="Sep"
	replace mon=10 if attempt12=="Oct"
	replace mon=11 if attempt12=="Nov"
	replace mon=12 if attempt12=="Dec"
	
			replace mon=smon if mi(mon)
			replace day=sday if mi(day)
			replace yr=syr if mi(yr)

	*drop if mon==9 & day<27
	*drop if mon<9

	drop attempt1* sdate sday smon
	ren attempt2 attempttime

	gen attemptdate=mdy(mon,day,yr)
	format attemptdate %td
	
			count if mi(attemptdate)
			if r(N)>0 {
				local misscount=r(N)
				file open missdate using "${output_dir}/missing_date", write replace
				file write missdate "`misscount' observations are missing submissiondate and attempt." ///
				" When checked manually, all values except CTO system vars are missing, but check again if number increases." ///
				" These obs were dropped."
				file close missdate 
				}	
				
	drop if mi(attemptdate)
	 /*  recreate submissiondate var for DMS ... must be in %td file
	gen sub_date_for_HFCs = submissiondate if !mi(submissiondate)
	replace sub_date_for_HFCs=attempt if mi(sub_date_for_HFCs)
	*/

	
******************* GENERATE DURATIONS ************************


*Recode tracking times (_start & _end) for sections into section durations
*by minute and by second
	foreach v of varlist *_end *_start {
		split `v', parse(" ") // split date from time
		split `v'2, parse(":") // remove semicolons
		destring `v'2*, replace
		ren `v'21 `v'_hour
		ren `v'22 `v'_min
		ren `v'23 `v'_sec
		gen `v'_totalmin=(`v'_hour*60*60+`v'_min*60+`v'_sec)/60 // multiply for seconds

		drop `v'_hour `v'_min `v'_sec // drop intermediate vars
	}

	//get difference in minutes b/w start&end
	foreach s of local sections {
		gen durmin_`s'=`s'_end_totalmin-`s'_start_totalmin if `s'_start1==`s'_end1 //if began & ended on same day
		replace durmin_`s'=.t if `s'_start1!=`s'_end1 //missing code: start & end on different days
		replace durmin_`s'=. if durmin_`s'<0 | durmin_`s'>120 //replace as missing if negative (not sure why this happens
			//but at least it doesn't happen that often) or if section took longer than 2 hours, which seems improbable
			//and must be a case of pausing a survey & finishing later.
	}

	gen durmin_total=(endtime-starttime)/60000
	replace durmin_total=. if durmin_total<0 //only true for 9 cases, don't know why
	replace durmin_total=.l if durmin_total>240 //if survey took longer than 4 hours, it must have stopped for a break and started again later

******************* RECODE OTHER SELECTIONS ************************


*Recode special selections as other
	*Recode all "other" selections as .o
		foreach v of varlist _all {
			capture confirm numeric variable `v'
			if !_rc {
				replace `v'=.o if `v'==-66
			}
			capture confirm string variable `v'
			if !_rc {
				replace `v'=".o" if `v'=="-66"
			}
		}
	*Recode all "don't know" as .d
		foreach v of varlist _all {
			capture confirm numeric variable `v'
			if !_rc {
				replace `v'=.d if `v'==-98
			}
			capture confirm string variable `v'
			if !_rc {
				replace `v'=".d" if `v'=="-98"
			}
		}
	*Recode all "refuse" as .r
		foreach v of varlist _all {
			capture confirm numeric variable `v'
			if !_rc {
				replace `v'=.r if `v'==-99
			}
			capture confirm string variable `v'
			if !_rc {
				replace `v'=".r" if `v'=="-99"
			}
		}
	*Recode all "override" as .v
		foreach v of varlist _all {
			capture confirm numeric variable `v'
			if !_rc {
				replace `v'=.v if `v'==-33
			}
			capture confirm string variable `v'
			if !_rc {
				replace `v'=".v" if `v'=="-33"
			}
		}
	*Recode all can't remember as .c
		foreach v of varlist _all {
			capture confirm numeric variable `v'
			if !_rc {
				replace `v'=.c if `v'==-96
			}
			capture confirm string variable `v'
			if !_rc {
				replace `v'=".c" if `v'=="-96"
			}
		}


*** STILL NEED TO RECODE -1 RESPONSES AND OTHER SPECIAL OVERRIDES 


******************* RECODE FOR ANALYSES ************************

/*Recodes used in original Lauch - 2019 
*Kutchova responses - recode to correct / incorrect

	//knows interest rate
	gen knowsinterest=.
	replace knowsinterest=1 if ku5_knowinterest==100
		//this question does not specify if the response should be in MWK or %, so I mark either as correct:
	replace knowsinterest=1 if ku5_knowinterest==10
	replace knowsinterest=0 if !mi(ku5_knowinterest) & ku5_knowinterest!=10 & ku5_knowinterest!=100
	
	//knows loan period
	gen knowdays=.
	replace knowdays=1 if ku6_knowdays==7
	replace knowdays=0 if !mi(ku6_knowdays) & ku6_knowdays!=7
	gen knowdays_thinks15=.
	replace knowdays_thinks15=1 if ku6_knowdays==15
	replace knowdays_thinks15=0 if !mi(ku6_knowdays) & ku6_knowdays!=15
	
	//knows late fee
	gen knowspen=.
		//again, question does not specify if answer should be % or MWK, so allowing both, based on 1000MWK
	replace knowspen=1 if ku6_knowpen==25 // = 2.5% of 1000 MWK
	replace knowspen=1 if ku6_asperc==2.5
	replace knowspen=0 if (!mi(ku6_knowpen) & ku6_knowpen!=25) | (!mi(ku6_asperc) & ku6_asperc!=2.5)
	
*/
******************* DUPLICATES ************************

*Create respondent type, create count attempt by day + tag duplicates
	
	//create respondent type
	gen noanswer=.
		replace noanswer=1 if phonecheck1==2 | phonecheck1==4 | phonecheck1==5 | phonecheck1==6
		replace noanswer=0 if phonecheck1==1 | phonecheck1==3
	gen ineligible=.
		replace ineligible=1 if age==0
		replace ineligible=1 if mobileagent!=4 & !mi(mobileagent)
		replace ineligible=0 if age==1 & mobileagent==4
	gen refuse=.
		replace refuse=1 if consent==0
		replace refuse=0 if consent==1
	gen resched=.
		replace resched=1 if !mi(reschedule_time)
	gen incomplete=.
		replace incomplete=1 if consent==1 & mi(fl2_knowinflationx)
	gen complete=.
		replace complete=1 if !mi(fl2_knowinflationx)
		replace complete=0 if mi(fl2_knowinflationx)

	foreach t in noanswer ineligible refuse resched incomplete complete {
		by phone, sort: egen tot_`t'=total(`t')
	}
	
	gen resptype=.
	replace resptype=1 if tot_noanswer>0
	replace resptype=2 if tot_ineligible>0
	replace resptype=3 if tot_refuse>0
	replace resptype=4 if tot_resched>0
	replace resptype=5 if tot_incomplete>0
	replace resptype=6 if tot_complete>0
	la def resptype 1 "No Answer" 2 "Ineligible" 3 "Refused" 4 "Rescheduled" 5 "Incomplete" 6 "Complete"
	la values resptype resptype
	la var resptype "Respondent Type"

	//Create attempt count by day
	by phone, sort: gen ct_attempt_${mon}_${day}=_N if mon==$mon & day==$day

	//Tag duplicate phone numbers
	duplicates tag phone, gen(dup)	

*Duplicate completed interviews:

/*I AM HERE!!!!!!! 


	//for completed interviews, drop other attempts
	drop if complete==0 & resptype==6 //drop unsuccessful attempts when phone later completed

	tempfile intermediate
	save `intermediate', replace

	//export list of duplicate complete
	sort phone

	keep if complete==1 & dup>0
	sort phone leader fo attemptdate
	export excel phone leader fo attempt using "${output_dir}/cum_duplicate_completed_interviews", firstrow(var) replace
	export excel phone leader fo attempt using "${output_dir}/daily_duplicate_completed_interviews" if day==$day & mon==$mon, firstrow(var) replace

	/*
	//IF DUPLICATE COMPLETE, SAVE 2ND INSTANCE AS BACKCHECK DATA
	sort phone attemptdate attempttime

	preserve
	by phone: keep if _n>1
	save "${bcdata_dir}/accidental_backcheck_dupsurvey", replace
	restore

	//IF DUPLICATE COMPLETE, REMOVE 2ND INSTANCE FROM MAIN DATA

	use `intermediate', clear
	merge 1:1 key using "${bcdata_dir}/accidental_backcheck_dupsurvey", gen(m)
	drop if m==3 // drop if matched

	//check that completed surveys are now unique
	preserve
	keep if complete==1
	isid phone
	restore

	//Drop duplicates
	drop if dup>0 & complete==0

	isid phone
	*/

/*NOT NEEDED ANYMORE
*Recode RCT treatment assignment
	// at some point, the CTO predata got mixed up treatment assignments, so that the 
	// survey data has incorrect treatment assignments -- get the correct assignments from the
	// sample data.
	ren phone msisdn
	merge 1:1 msisdn using "${dice_dir}\06_Data\05_Survey\00_impact_survey_sample_second.dta", gen(MERGE)
	drop if MERGE==2 //only in sample, not in survey data
	merge 1:1 msisdn using "${dice_dir}\06_Data\05_Survey\00_impact_survey_sample_duplicate.dta", gen(MERGE2)
	drop if MERGE2==2
	
	// the var treat is from the sample assignments, this is the true treat assignment
	tab treat finlit // 5 obs do not match with the survey data's treatment assignment... strange,bad.
	tab treat salience //1 ob does not match
	tab treat infosms //no one is assigned here in the CTO data
	tab treat control //1 ob doesn't match
	
	tab resptype treat, col nofreq
	
*ID each respondent as belonging to which sample
	gen sample1=(MERGE2==3) //matched
	gen sample2=(MERGE==3)

	merge 1:1 msisdn using "${dice_dir}\06_Data\05_Survey/RD_Sample1_Loan1000", gen(MERGE3)
	gen sample3=(MERGE3==3)
	
	/*  TURN THIS CODE ON AFTER SURVEY RELAUNCHES 
	merge 1:1 msisdn using "${dice_dir}\06_Data\05_Survey/RD_Sample2_Loan1000", gen(MERGE4)
	gen sample4=(MERGE4==3)
	*/
	
	gen sample=1 if sample1==1
	replace sample=2 if sample2==1
	replace sample=3 if sample3==1
	replace sample=4 if sample4==1
	la define sample 1 "RCT1" 2 "RCT2" 3 "RD1" 4 "RD2"
	la val sample sample
	
	// there are 1941 phone numbers who are not in any sample, nor were they surveyed
	// (check this by tabbing resptype sample - none who are missing sample1
	// have a resptype).  These are mixed in somehow from KYC data or from list of
	// Kutchova eligible.  Can drop these.
	drop if mi(sample)
	
	*/
*************************************************
******************* END ************************

	save "${surveydata_dir}/${surveyname}_cleaned", replace
	save "${mostrecent_data}/${surveyname}_cleaned", replace

//use "${mostrecent_data}/${surveyname}_cleaned"
