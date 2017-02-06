@LAZYGLOBAL OFF.
PARAMETER parString TO "".
//Initiate Setup values
LOCAL pidName TO "Throttle pid".							//Name of the Pid that your Tuning
						
LOCK input TO SHIP:AIRSPEED.								//Input for the Pid
LOCAL inputName TO "SHIP:AIRSPEED".							//Name of the input
LOCAL SetPoint TO 120.										//Default Setpoint
LOCAL setupValue TO 1.										//Value to set OutputTo to when getting to setPoint

LOCAL outPut TO 0.											//Default output value of the pid
FUNCTION outPutTO {											//What to do with the output
	LOCK THROTTLE TO outPut.						
}						
LOCAL outPutToName TO "Throttle".							//Name of the OutputTo
LOCAL minOutPut TO 0.										//Minimun Output for the pid
LOCAL maxOutPut TO 1.										//Max Output for the pid
	
LOCAL measuringTime TO 60.									//How long data is added in seconds
LOCAL kuList TO LIST(0.0001,0.001,0.01,0.1,1,10).			//Default Ku list

LOCAL defaultPath TO "0:/Develop/Tunepid/"+pidName+"/". 	//Default path for the output files

FUNCTION BelowSetPoint {
	//What to do when below SetPoint.
	
	LOCK THROTTLE TO setupValue.
	ActionLog("Waiting for "+inputName+" to be above "+setPoint, "HUD").
	UNTIL input > setPoint.
	LOCK  THROTTLE TO 0.
	WAIT 0.5.
}

FUNCTION AboveSetPoint {
	//What to do when above Setpoint.
	
	LOCK THROTTLE TO 0.
	ActionLog("Waiting for "+inputName+" to be below "+setPoint, "HUD").
	UNTIL input < setPoint.
	WAIT 0.5.
}

FUNCTION launch {
	//Launch commands or script
	
	LOCK THROTTLE TO 1.
	SAS OFF.
	IF ALT:RADAR < 100 {
		ActionLog("Launch","PRINT").
		BRAKES OFF.
		STAGE.
		LOCK STEERING TO HEADING(90,0).
		UNTIL SHIP:AIRSPEED > 60 {}
		LOCK STEERING TO HEADING(90,10).
		UNTIL ALT:RADAR > 100 {}
		GEAR OFF.
		
	}
	IF ALT:RADAR < 3000 {
		LOCK STEERING TO HEADING(90,20).
		LOCK THROTTLE TO 0.7.
		ActionLog("Waiting for Altitude above 3 km from the ground.","PRINT").
		UNTIL ALT:RADAR > 3000 {}
	}
	LOCK STEERING TO HEADING(90,10).
}

RUNPATH("0:/Develop/Tunepid/template/TunePidLib.ks").
