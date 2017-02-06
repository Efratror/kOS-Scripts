@LAZYGLOBAL OFF.
PARAMETER parString TO "".


//Initiate Setup values
LOCAL pidName TO "pidName".							//Name of the Pid that your Tuning
				
LOCK input TO "input".								//Input for the Pid
LOCAL inputName TO "inputName".						//Name of the input
LOCAL SetPoint TO 0.								//Default Setpoint
LOCAL setupValue TO 0.								//Value to set OutputTo to when getting to setPoint
				
LOCAL outPut TO 0.									//Default output value of the pid
FUNCTION outPutTO {									//What to do with the output				
}				
LOCAL outPutToName TO "outPutToName".				//Name of the OutputTo
LOCAL minOutPut TO 0.								//Minimun Output for the pid
LOCAL maxOutPut TO 1.								//Max Output for the pid
				
LOCAL measuringTime TO 60.							//How long data is added in seconds
LOCAL kuList TO LIST(0.0001,0.001,0.01,0.1,1,10).	//Default Ku list

LOCAL defaultPath TO "0:/"+pidName+"/". 			//Default path for the output files

FUNCTION BelowSetPoint {
	//What to do when below SetPoint.
	
}

FUNCTION AboveSetPoint {
	//What to do when above Setpoint.
	
}

FUNCTION launch {
	//Launch commands or script
	
}

RUNPATH("0:/TunePidLib.ks").
