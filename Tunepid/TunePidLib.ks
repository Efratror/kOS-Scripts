@LAZYGLOBAL OFF.

CLEARSCREEN.
//Default values for parameter booleans
LOCAL help TO FALSE. 				//
LOCAL resetActionLog TO FALSE.   	//
LOCAL jsonFile TO FALSE.        	//
LOCAL debug TO FALSE.           	//

//Default setup
LOCAL sdiv TO "".					//


Screendivider().
PRINT sdiv.
PrintCenter("Tune "+pidName,0).

ParameterFunct().

IF NOT help {
	ActionLog("Log start: ","NULL","BEGIN").
	LOCAL dataPath TO defaultPath+"data/".
	IF NOT EXISTS(defaultPath) {CREATEDIR(defaultPath).}
	IF NOT EXISTS(dataPath) {CREATEDIR(dataPath).}

	LOCAL mode TO "NULL".
	LOCAL outputTable TO LIST().
	LOCAL y TO 0.
	
	
	//Setting up the Kulist defined by the default list or bij a json file.
	IF jsonFile = FALSE {
		SET mode TO 0.
		ActionLog("Using default Ku list, mode is 0.","NULL").
	}
	ELSE {
		IF jSonFile:CONTAINS("0:/") AND jsonFile:CONTAINS(".json"){
			ActionLog("Using pre-build json file", "HUD").
			SET y TO y+1.
			SET kuList TO READJSON(jsonFile).
			IF jsonFile:CONTAINS("mode1") {
				SET mode TO 1.
				ActionLog("Mode is 1","NULL").
			}
			ELSE IF jsonFile:CONTAINS("mode2"){
				SET mode TO 2.
				ActionLog("Mode is 2","NULL").
			}
			ELSE IF jsonFile:CONTAINS("Output"){
				SET mode TO 3.
				ActionLog("Mode is 3","NULL").
				SET outputTable TO READJSON(jsonFile).
			}
			ELSE {
				SET mode TO 0.
				ActionLog("WARNING: Mode name not found in filename, mode is 0","HUD").
				ActionLog("filename: "+jsonFile,"NULL").
			}
			
		}
		ELSE {
			ActionLog("ERROR: Filename isn't correct check it's path and name", "HUD").
			ActionLog("Filename:"+jsonFile,"NULL").
			ActionLog("Continue with default Ku list and mode is 0","NULL").
			SET mode TO 0.
		}
	}


	IF mode = "Null" {ActionLog("ERROR: Mode wasn't set.","HUD").}
	IF mode=0 or mode = 1 {IF DEFINED launch {launch().}}
	IF mode = 0 {
		//First run of the tuning function where the values 
		//to furter investigate are determined.
		
		SET mode TO mode+1.
		ActionLog("Start first measuring with Init Kp list", "NULL").
		SET kuList TO Tuning(kuList).
		
		ActionLog("measurments of first Kp list compleet", "NULL").
		ActionLog("Returned list: ", "NULL").
		ActionLog(kuList, "NULL").
		
		LOCAL json TO defaultPath+"Return-mode1.json".
		WRITEJSON(kuList,json).
	}
	
	IF mode = 1 {
		//Second run of the tuning function where 
		//the amplitude change and amplitude period are decided.
		//This mode builds his own Kulist from the output of mode 0.
		
		SET mode TO mode+1.
		ActionLog("Building next Kp list", "NULL").
		SET kuList TO BuildRange(kuList[0],kuList[kuList:LENGTH-1],0.5).

		ActionLog("Next Kp list: ", "NULL").
		ActionLog(kuList, "NULL").

		ActionLog("Start second measuring with second Kp List","NULL").
		SET kuList TO Tuning(kuList).
		
		LOCAL json TO defaultPath+"Return-mode2.json".
		WRITEJSON(kuList,json).
	}
	
	IF mode = 2{
		//This mode uses the output from mode 1 to 
		//build a list of the ideal settings for a pid.
		//Can return more than one set of settings!
		//Adds title and end row to the output list.
	
		SET mode TO mode+1.
		SET kuList TO HeigestPoints(2,kuList).
		
		IF kuList:LENGTH > 1 {
			ActionLog("Warning: Ku list is longer than one","HUD").
		}
		
		FROM {LOCAL r TO 0.} UNTIL r > kuList:LENGTH-1 STEP{SET r TO r+1.} DO {
			LOCAL Ku TO kuList[r][0].
			LOCAL Tu TO ROUND(kuList[r][2],3).
			LOCAL Kp TO 0.
			
			outputTable:ADD(LIST("Period: "+Tu+" s")).
			outputTable:ADD((LIST("Controle Type","Kp","Ki","Kd"))).
			SET Kp TO 0.5*Ku.
			outputTable:ADD(LIST("P",Kp,0,0)).
			
			SET Kp TO 0.45*Ku.
			outputTable:ADD(LIST("PI",Kp,1.2*Kp/Tu,0)).
			
			SET Kp TO 0.8*Ku.
			outputTable:ADD(LIST("PD",Kp,0,Kp*Tu/8)).
			
			SET Kp TO 0.6*Ku.
			outputTable:ADD(LIST("classic PID",Kp,2*Kp/Tu,Kp*TU/8)).
			
			SET Kp TO 0.7*Ku.
			outputTable:ADD(LIST("Pessen Integral Rule",Kp,0.4*Kp/Tu,0.15*Kp*Tu)).
			
			SET Kp TO 0.33*Ku.
			outputTable:ADD(LIST("Some overshoot",Kp,2*Kp/Tu,Kp*Tu/3)).
			
			SET Kp TO 0.2*Ku.
			outputTable:ADD(LIST("No overshoot",Kp,2*Kp/Tu,Kp*Tu/3)).
			
			outputTable:ADD(LIST(" ")).
			
			//Rounding the integers
			LOCAL rowStart TO 2.
			IF outputTable:LENGTH > 10 {SET rowStart TO rowStart+10.}
			FROM {LOCAL row TO rowStart.} UNTIL row = outputTable:LENGTH-1 STEP{SET row TO row+1.} DO {
				ActionLog("Round row "+row,"DEBUG").
				SET outputTable[row][1] TO ROUND(outputTable[row][1],3).
				SET outputTable[row][2] TO ROUND(outputTable[row][2],3).
				SET outputTable[row][3] TO ROUND(outputTable[row][3],3).
			}
			LOCAL json TO defaultPath+"Output.json".
			WRITEJSON(outputTable,json).
		}
	}
	
	IF mode = 3 {
		//Builds the output table on screen.
		BuildTable(outputTable).
	}

	PRINT " ".
	ActionLog("Log ended at","NULL","END").
	SAS ON.

	FUNCTION Tuning {
		PARAMETER KpList.
		SAS OFF.
		LOCAL x TO 0. //value for the kpList index
		
		//Pid Setup
		LOCAL tunePID TO PIDLOOP().
		SET tunePID:KP TO KpList[x].
		SET tunePID:KI TO 0.
		SET tunePID:KD TO 0.
		SET tunePID:MAXOUTPUT TO maxOutput.
		SET tunePID:MINOUTPUT TO minOutput.
		SET tunePID:SETPOINT TO SetPoint.
		LOCK p TO tunePID:PTERM.
		SET OutPut TO tunePID:UPDATE(TIME:SECONDS,input).
		
		// Data lists
		LOCAL DataList TO LIST().		//Measured Data List
		LOCAL jsonFile TO 0.			//Json file for the data list
		LOCAL returnList TO LIST(). 	//Default returnList.
		
		//Start time of the script
		LOCAL startTime TO TIME.						//Current time
		LOCK changeKpTime TO startTime+measuringTime. 	//Time when the measuring is over
		
		LOCAL end TO FALSE.
		
		IF mode = 2 {returnList:ADD("Kp,Amplitude Change,Amplitude Period").}
		InitPoint().

		//Loop till the end of the Kulist.
		UNTIL end {
			SET output TO tunePID:UPDATE(TIME:SECONDS,input).
			
			IF TIME:SECONDS > changeKpTime {
				//If measuring time has ended: 
				//  set Ku to the next Ku on the list
				//  reinitiate to setpoint.
				
				NextKp(FALSE).
				InitPoint().
			}
			IF input < setPoint - 20 OR input > setPoint + 20 {
				//If the input is 20 below or above setpoint:
				//  set Ku to the next Ku on the list
				//  reinitiate to setpoint
				
				ActionLog("WARNING: with Kp set at "+kpList[x]
				+" the output isn't changing fast enough","HUD").
				NextKp().
				InitPoint().
			}
			IF P < -2 OR p > 2 {
				//If the proportional term is -2 below or above 2:
				//  set Ku to the next Ku on the list
				//  reinitiate to setpoint
				
				ActionLog("WARNING: with Kp set at "+kpList[x]
				+" the Proportional value is changing to fast","HUD").
				NextKp().
				InitPoint().
			}
			Display().
			DataList:ADD (dataListLine).

		}
		RETURN returnList.
		
		FUNCTION InitPoint {
			//Function to reset the plane and pid to setpoint.
			ActionLog("Getting to setPoint","NULL").
			IF input < setPoint {belowSetPoint.}
			ELSE {AboveSetPoint.}
			outPutTo().
			CLEARSCREEN.
			tunePID:RESET.
			WAIT 0.1.
			SET startTime TO TIME.
			Display(TRUE).
			dataStart().
		}

		FUNCTION NextKp {
			//Function to change Ku to the next one on the list if there is one.
			//and build a json file for the current data.
			PARAMETER forcedChange TO TRUE.
			
			IF forcedChange = FALSE {
				//If measuring time has ended
				//  For mode 1 add Ku to the return list
				//  For mode 2 calculate amplitude change 
				//    and period and add those to the return list
				ActionLog("Measuring time ended", "HUD").
				IF mode = 1 {
					returnList:ADD (kpList[x]).
				}
				ELSE IF mode = 2 {
					ActionLog("Calculating amplitude change and period","HUD").
					LOCAL heigestpointsList TO HeigestPoints(4,DataList).
					LOCAL amplitudeChange TO GetAmplitudeChange(heigestpointsList).
					LOCAL amplitudePeriod TO GetPeriod(heigestpointsList).
				
					returnList:ADD (LIST(kpList[x],amplitudeChange,amplitudePeriod)).
				}
				WRITEJSON(dataList,jsonFile).
				SET dataList TO LIST().
			}
			
			// If there are more Ku's in the list pick the next one else go further with the main code.
			IF x <> kpList:LENGTH-1 {
				ActionLog("Changing kp from "+kpList[x]+" to "+kpList[x+1],"HUD").
				SET tunePID:KP TO kpList[x+1].
				SET x TO x+1.
			}
			ELSE {
				SET end TO TRUE. 
				SAS ON.
				ActionLog("Data collection ended","HUD").
			}
		}
		
		FUNCTION DataStart {
			//Function to start a new list of data values
			//and delete the old one.
			ActionLog("Starting new Kp list","NULL").
			SET jsonFile TO dataPath+"Kp"+tunePID:KP+".json".
			
			IF EXISTS(jsonFile){DELETEPATH(jsonFile).}
			
			dataList:ADD (LIST("# Start time: "+startTime:CALENDAR+" "+startTime:CLOCK)).
			dataList:ADD (LIST("# Kp "+kpList[x])).
			dataList:ADD (LIST(" ")).
			dataList:ADD (LIST("time after start","p",inputName)).
			
			LOCK dataListLine TO LIST((TIME:SECONDS-startTime:SECONDS),p,input).
		}

		FUNCTION Display {
			//Function to build the display
			PARAMETER init TO FALSE.
			
			LOCAL yStart TO 7.
			LOCAL spaceString TO "        ".
			IF init {
				PRINT sdiv.
				PrintCenter("Tune "+pidName,0).
				PRINT "Input from: "+inputName.
				PRINT "Set point:  "+ROUND(setPoint,2).
				PRINT "Output to:  "+outPutToName.
				PRINT "Start time: "+startTime:CALENDAR+" "+startTime:CLOCK.
				PRINT "Waiting time for changing KP: "+measuringTime+"s".
				PRINT " ".
				PRINT "Current Values:".
				PRINT "   input  "+ROUND(input,2)+spaceString.
				PRINT "   output "+ROUND(outPut,2)+spaceString.
				PRINT "   p      "+ROUND(p,4)+spaceString.
				PRINT "   Kp     "+kpList[x]+spaceString.
				PRINT " ".
				PRINT "   time till kp change "+(changeKpTime-time):CLOCK+spaceString.
				PRINT " ".
			}
			
			PRINT "   input  "+ROUND(input,2)+spaceString AT (0,yStart+1).
			PRINT "   output "+ROUND(outPut,2)+spaceString AT (0,yStart+2).
			PRINT "   p      "+ROUND(p,4)+spaceString AT (0,yStart+3).
			PRINT "   Kp     "+kpList[x]+spaceString AT (0,yStart+4).
			PRINT "   time till kp change "+(changeKpTime-time):CLOCK+spaceString AT (0,yStart+6).
		}

		FUNCTION GetPeriod {
			//Function to get the period of the amplitude
			PARAMETER dataList.
			ActionLog("Calculating amplitude period","NULL").
			RETURN (dataList[1][0]-dataList[0][0]).
		}
		
		FUNCTION GetAmplitudeChange {
			//Function to get the change of amplitude.
			PARAMETER dataList.
			ActionLog("Calculating amplitude change","NULL").
			LOCAL dY TO dataList[dataList:LENGTH-1][1]-dataList[0][1].
			LOCAL dX TO dataList[dataList:LENGTH-1][0]-dataList[0][0].
				
			RETURN (dY/dX).
		}
	}
	
	FUNCTION BuildRange {
		//Function to build a custom range.
		//Used for a list of Ku list to determin the ideal pid settings.
		PARAMETER start, end, step.

		LOCAL rangeList TO LIST().
		FROM {LOCAL s TO start.} UNTIL s > end STEP {SET s TO s+(start*step).} DO {
			rangeList:ADD (s).
		}
		rangeList:ADD (end).
		RETURN rangeList.
	}

	FUNCTION HeigestPoints {
		//Function to get the heigest points of the datalist,
		//thats is created by the tuning function.
		PARAMETER i, datalist.
		
		ActionLog("Calculating heigest points ","NULL").
		LOCAL heigestpointsList TO LIST().
		FROM {LOCAL r TO i.} UNTIL r = datalist:LENGTH-1 STEP {SET r TO r+1.} DO {
			IF r < datalist:LENGTH-2 {
				IF datalist[r][1] > datalist[r-1][1] AND datalist[r][1] > datalist[r+1][1]{
					IF dataList[r]:LENGTH = 3 {
						heigestpointsList:ADD (LIST(datalist[r][0],dataList[r][1],dataList[r][2])).
					}
					ELSE {
						heigestpointsList:ADD (LIST(datalist[r][0],dataList[r][1])).
					}
				}
			}
		}
		RETURN heigestpointsList.
	}

	FUNCTION BuildTable {
		//Function to convert a list to a table. 
		PARAMETER data, logPath TO FALSE.
		
		PRINT sdiv.
		SET y TO data:LENGTH.
		LOCAL specialData TO LIST().
		LOCAL collumMaxLength TO LIST().
		LOCAL rDiv TO "".
		PRINT " ".
		
		//loop to check the data for title(s) and end(ings) row(s) 
		//and adds them to a specialData list
		ActionLog("Making specialData list","NULL").
		FROM {LOCAL r TO 0. LOCAL tableStart TO FALSE.} UNTIL r=data:LENGTH STEP {SET r TO r+1.} DO {
			ActionLog("r: "+r ,"DEBUG").
			IF tableStart = FALSE {
				ActionLog("data[r]:LENGTH "+data[r]:LENGTH,"DEBUG").
				IF data[r]:LENGTH = 1{
					specialData:ADD(LIST(r,"Title")).
					ActionLog("Title found at row "+r+" Title: "+data[r][0],"DEBUG").
				} 
				ELSE {
					specialData:ADD(LIST(r,"No Title")).
					ActionLog("No title found begin of table is row: "+r,"DEBUG").
				}
				SET tableStart TO TRUE.
			}
			IF data[r][0] = " " {
				specialData:ADD(LIST(r,"End")). 
				SET tableStart TO FALSE.
				ActionLog("End of table found at row: "+r,"DEBUG").
			}
		}
		
		//Loop to go over the rows and print it's data
		
		//If the row is the begin of a table and a title
		//   print the row, an empty line,
		//   the first row of the collum and a divider.
		//If the row is the begin of a table but doesn't contain a title
		//   print the row and the divider.
		//If the row is the end of a table
		//   print the divider and the row
		//If the row is not special
		//   print the row
		
		ActionLog("specialData list "+specialData,"NULL").
		ActionLog("Printing Table","NULL").
		FROM {LOCAL r TO 0. LOCAL i TO 0.LOCAL firstTableRow TO 0.} UNTIL r=data:LENGTH STEP {SET r TO r+1.} DO {
			IF r = specialData[i][0] {
				IF specialData[i][1] = "Title" {
					ActionLog("Printing Title from row: "+r+" Title:"+data[r],"DEBUG").
					SET firstTableRow TO r+1.
					MaxLengthCollum().
					PrintLog(data[r][0]).
					PrintLog(" ").
					PrintRow(data[r+1]).
					PrintLog(rDiv).
					SET r TO r+1.
					SET y TO y+2.
				}
				ELSE IF specialData[i][1]="No Title" {
					ActionLog("Printing first row from row: "+r,"DEBUG").
					SET firstTableRow TO r.
					MaxLengthCollum().
					PrintRow(data[r]).
					PrintLog(rDiv).
					SET y TO y+2.
				}
				ELSE IF specialData[i][1]="End" {
					ActionLog("Printing end of table from row: "+r,"DEBUG").
					PrintLog(rDiv).
					PrintLog(data[r][0]).
					SET collumMaxLength TO list().
					SET y TO y+2.
				}
				SET i TO i+1.
			}
			ELSE {
				ActionLog("Nothing special found printing row","DEBUG").
				PrintRow(data[r]).
			}
		
			FUNCTION PrintRow {
				//Function to print a row
				//Checks every collum of the row for string or other and prints it
				PARAMETER Row.
				LOCAL rowString TO "".
				ActionLog("row is "+row,"DEBUG").
				ActionLog("data[r]:LENGTH "+row:LENGTH,"DEBUG").
				FROM {LOCAL c TO 0.} UNTIL c = row:LENGTH STEP {SET c TO c+1.} DO {
					
					ActionLog("row: "+r+" col: "+c,"DEBUG").
					ActionLog("data[r][c] :"+row[c],"DEBUG").
					IF Row[c]:TYPENAME() = "String" {
						SET rowString TO rowString+row[c]+space+" |".
					}
					ELSE {
						SET rowString TO rowString+space+" "+row[c]+"|".
					}
					
					FUNCTION Space {
						//Function to determin the extra spaces needed to get even collums
						LOCAL spaceString TO "".
						FROM {
							LOCAL spaceLength TO collumMaxLength[c]-row[c]:TOSTRING:LENGTH.
							LOCAL int TO 0.
						} UNTIL int = spaceLength STEP {SET int TO int+1.} DO{SET spaceString TO spaceString+" ".}
						ActionLog("spaceString Length: "+spaceString:LENGTH,"DEBUG").
						RETURN spaceString.
					}
				}
				ActionLog("Row String: "+rowString,"DEBUG").
				PrintLog(rowString).			
			}
			
			FUNCTION MaxLengthCollum {
				//Function to get the lengt of the longest collum
				//and build a divider for the total table length.
				SET rDiv TO "".
				FROM {LOCAL c to 0.} UNTIL c = data[firstTableRow]:LENGTH STEP {SET c TO c+1.} DO {
					LOCAL maxLength TO 0.
					FROM {LOCAL row TO firstTableRow.} until row = specialData[i+1][0] STEP {SET row TO row+1.} DO{
						LOCAL collumLength TO data[row][c]:TOSTRING:LENGTH.
						IF collumLength > maxLength {SET maxLength TO collumLength.}
					}
					collumMaxLength:ADD(maxLength).
				}
				rDivBuild().
				
					FUNCTION rDivBuild {
						//Function to build the divider.
						LOCAL rDivString TO "-".
						LOCAL int TO 0.
						LOCAL tableLength TO collumMaxLength:LENGTH*3+1.
						
						UNTIL int = collumMaxLength:LENGTH-1 {
							SET tableLength TO tableLength+collumMaxLength[int].
							SET int TO int+1.
						}
						FROM {LOCAL s TO 0.} UNTIL s=tableLength STEP {SET s TO s+1.} DO {SET rDiv To rDiv+rDivString.}
					}
			}
			
			FUNCTION PrintLog {
				//Function to print and log a string.
				PARAMETER string.
				
				PRINT string.
				LOG string TO defaultPath+"/"+pidName.
			}
		}
	}
}

FUNCTION ActionLog{
	//Function to build a log of the actions.
	PARAMETER string, action, init TO FALSE.
	
	LOCAL logTime TO TIME:CALENDAR+" "+TIME:CLOCK.
	LOCAL actionLogFile TO defaultPath+"log.txt".
	
	IF init = "BEGIN"{
		IF resetActionLog AND EXISTS(actionLogFile){
			DELETEPATH(actionLogFile).
			LOG "Removed last Log File" TO actionLogFile.
		}
		LOG string+logTime TO actionLogFile.
		LOG " " TO actionLogFile.
		LOG "script setup: " TO actionLogFile.
		LOG "   Tuning Pid:      "+pidName TO actionLogFile.
		LOG "   log path:        "+defaultPath TO actionLogFile.
		LOG "   Change Kp after: "+measuringTime+"s" TO actionLogFile.
		LOG "   Initial kuList   "+kuList TO actionLogFile.
		LOG " " TO actionLogFile.
		LOG "PID setup: " TO actionLogFile.
		LOG "   Input from:      "+inputName TO actionLogFile.
		LOG "   setPoint:        "+SetPoint TO actionLogFile.
		LOG "   Output to:       "+outPutToName TO actionLogFile.
		LOG "   Minimum output:  "+minOutPut TO actionLogFile.
		LOG "   Maximum output:  "+maxOutPut TO actionLogFile.
		LOG " " TO  actionLogFile.
	}
	ELSE IF init = "END" {
		LOG " " TO actionLogFile.
		LOG string+" "+logTime TO actionLogFile.
	}
	ELSE IF action = "DEBUG" AND debug{ LOG logTime+": "+string TO actionLogFile.}
	ELSE IF action = "DEBUG" AND NOT debug{}
	ELSE {
		IF action = "HUD" {
			IF string:CONTAINS("ERROR") {
				HUDTEXT(string, 8, 2, 20, red, true).
				
			}
			IF string:CONTAINS("WARNING"){
				HUDTEXT(string, 6, 2, 20, yellow, true).
			}
			ELSE {
				HUDTEXT(string, 4, 2, 20, white, true).
			}
		}
		ELSE IF action = "PRINT" {
			PRINT string.
			
		}
		LOG logTime+": "+string TO actionLogFile.
	}
}

FUNCTION ParameterFunct {
	//Function to set parameters.
	
		IF parString:CONTAINS("-h") or parString:CONTAINS ("-help") {
			SET help TO TRUE.
		}
		
		IF parString:CONTAINS("-r") or parString:CONTAINS("-rewrite") {
			SET resetActionLog TO TRUE.
		}
		IF parString:CONTAINS (")") {
			IF parString:CONTAINS("-j(") OR parString:CONTAINS("-json(") {
				LOCAL part1 TO parString:SPLIT("(").
				LOCAL part2 TO part1[1]:SPLIT(")").
				SET jsonFile TO part2[0].
			
			}
		}		
		IF parString:CONTAINS("-d") OR parString:CONTAINS("-debug") {
			SET debug TO TRUE.
		}
	
	IF parString <> "" {
		IF help = FALSE AND resetActionLog = FALSE AND jSonFile = FALSE AND debug = FALSE {
			SET help TO TRUE.
			PRINT "Unreconized or incompleet command line".
		}
	}
	IF help {
		PRINT " ".
		PRINT "Help:".
		PRINT "   -h / -help               : parameterlist".
		PRINT "   -j(path) / -json(path)   : add a json list".
		PRINT "                              path is a file location to a json file.".
		PRINT "   -r / -rewrite            : start with a clean action logfile.".
		PRINT " ".
		PRINT sdiv.
		PRINT "Script version: 1.0".
		PRINT " ".
	}
}

FUNCTION Screendivider {
	FROM {LOCAL inc TO 0.} UNTIL inc = TERMINAL:WIDTH STEP{SET inc TO inc+1.} DO{
		SET sdiv TO sdiv+"-".
	}
}

FUNCTION PrintCenter {
	PARAMETER string, y.
	
	LOCAL screenCenter TO TERMINAL:WIDTH/2.
	LOCAL stringCenter TO string:TOSTRING:LENGTH/2.
	
	PRINT string AT (screenCenter-stringCenter,y).
}
