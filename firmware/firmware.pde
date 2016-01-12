/*******************************************************************************
*firmware.pde
*
*Firmware for the BabyBioBox project
*******************************************************************************/
#include <Wire.h>

#define ARD_CTS 4
#define ARD_ON_SLEEP 6
#define ARD_MCP_INT 7
#define ARD_STAT_BLUE 9
#define ARD_STAT_GREEN 10
#define ARD_STAT_RED 11
#define ARD_SEND_LED 13

#define MCP_WET 0
#define MCP_DIRTY 1
#define MCP_FEED 2
#define MCP_SLEEP 3
#define MCP_WAKE 4
#define MCP_SEND 5
#define MCP_ADDR 0x20

#define RTC_ADDR 0x68

#define S_PIN_MASK 0xFE
#define WARN_TIMEOUT 120000UL
#define RESET_TIMEOUT 150000UL
#define DEBOUNCE_WINDOW 100L
//play with buttons and the scope to figure out how long the debounce window actually needs to be
#define SETUP_TIMEOUT 400L
#define MAX_RETRIES 3

typedef unsigned char uchar;

typedef struct _ledStateSpace
{
	unsigned long wetUpTime;
	unsigned long dirtyUpTime;
	unsigned long feedUpTime;
	unsigned long sleepUpTime;
	unsigned long wakeUpTime;
	unsigned long sendUpTime;
	// unsigned long redUpTime;
	// unsigned long greenUpTime;
	// unsigned long blueUpTime;
	unsigned long rgbUpTime;
	unsigned int wetState;
	unsigned int dirtyState;
	unsigned int feedState;
	unsigned int sleepState;
	unsigned int wakeState;
	unsigned int sendState;
	// unsigned int redState;
	// unsigned int greenState;
	// unsigned int blueState;
	unsigned int rgbState;
	uchar wetVal;
	uchar dirtyVal;
	uchar feedVal;
	uchar sleepVal;
	uchar wakeVal;
	uchar sendVal;
	uchar redVal;
	uchar greenVal;
	uchar blueVal;
} ledStateSpace;


void init_mcp();
void set_mcp_pin(uchar pin, int state);
void set_mcp_all(int state);
uchar read_mcp_reg(uchar readReg)
void set_mcp_reg(uchar writeReg,uchar value)
void setRGB_led(uchar red, uchar green, uchar blue)
void keypressInterrupt()
void process_state()
void updateAnimations()
void updateSendAnimation()
void updateRGBAnimation()
uchar set_canSleep(uchar newVal)
uchar send_data()

ledStateSpace stateSpace;
//int state=HIGH;
//uchar testPin=0;
unsigned long lastInteractTime=0;
unsigned long lastReadTime=0;
int sendPressCount=0;
uchar setState=0;
uchar oldSetState=0;
uchar animState=0;
uchar lastReadState=0;
volatile uchar readNeeded=0;
volatile uchar canSleep=0;

void setup()
{
	pinMode(ARD_CTS, INPUT);
	pinMode(ARD_ON_SLEEP,INPUT);
	pinMode(ARD_STAT_RED,OUTPUT);
	pinMode(ARD_STAT_GREEN,OUTPUT);
	pinMode(ARD_STAT_BLUE,OUTPUT);
	pinMode(ARD_SEND_LED,OUTPUT);
	pinMode(ARD_MCP_INT,INPUT);

	stateSpace.wetUpTime=0;
	stateSpace.dirtyUpTime=0;
	stateSpace.feedUpTime=0;
	stateSpace.sleepUpTime=0;
	stateSpace.wakeUpTime=0;
	stateSpace.sendUpTime=0;
	// stateSpace.redUpTime=0;
	// stateSpace.greenUpTime=0;
	// stateSpace.blueUpTime=0;
	stateSpace.rgbUpTime=0;
	stateSpace.wetState=0;
	stateSpace.dirtyState=0;
	stateSpace.feedState=0;
	stateSpace.sleepState=0;
	stateSpace.wakeState=0;
	stateSpace.sendState=0;
	// stateSpace.redState=0;
	// stateSpace.greenState=0;
	// stateSpace.blueState=0;
	stateSpace.rgbState=0;
	stateSpace.wetVal=0;
	stateSpace.dirtyVal=0;
	stateSpace.feedVal=0;
	stateSpace.sleepVal=0;
	stateSpace.wakeVal=0;
	stateSpace.sendVal=0;
	stateSpace.redVal=0;
	stateSpace.greenVal=0;
	stateSpace.blueVal=0;

	Serial.begin(9600);
	Serial1.begin(9600);
	Wire.begin();
	init_mcp();

	stateSpace.rgbState=1;//for testing
}

void loop()
{
	//Realized that this debounce wouldn't work if used only when an interrupt 
	//occurs.  Will instead use the interrupt to wake the processor back up when
	//a button is pressed.
		uchar readState=read_mcp_reg(0x13); //read gpio b
		if(readState!=lastReadState)
		{
			if(millis()-lastReadTime >= DEBOUNCE_WINDOW)
			{
Serial.print("setState ");
Serial.println(setState);
Serial.print("readState ");
Serial.println(readState);
				lastReadTime=millis();
				lastReadState=readState;
				setState= setState ^ readState; //first press to enable second press to clear
			}
		}
	//switching to active low interrupts /should/ obviate the need for the digitalRead.
	//readNeeded=digitalRead(MCP_INT_PIN);
	//digitalWrite(ARD_SEND_LED,readNeeded);
	process_state();
	if(canSleep)
	{
		attachInterrupt(digitalPinToInterrupt(ARD_MCP_INT),keypressInterrupt,LOW);
	}
}

void init_mcp()
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x00);
	Wire.write(0x00);  //0x00 - IODIRA -	All output
	Wire.write(0x3F);  //0x01 - IODIRB -	Pins 0-5 are input
	Wire.write(0x00);  //0x02 - IPOLA  -	Input polarity matches input value
	Wire.write(0x3F);  //0x03 - IPOLB  -	Input polarity is inverted because of pullups.
	Wire.write(0x00);  //0x04 - GPINTENA -	No interupts on the output pins
	Wire.write(0x3F);  //0x05 - GPINTENB -	Interuputs on input pins
	Wire.write(0x00);  //0x06 - DEFVALA
	Wire.write(0x00);  //0x07 - DEFVALB  -	Default state is unpressed buttons
	Wire.write(0x00);  //0x08 - INTCONA
	Wire.write(0x3F);  //0x09 - INTCONB
	Wire.write(0x00);  //0x0A - ICONN - see below for configuration description
	Wire.write(0x00);  //0x0B - ICONN
	//^ unified registers, non-mirrored ints, sequential mode, slew disabled, active ints, active low
	Wire.write(0x00);  //0x0C - GPPUA
	Wire.write(0x3F);  //0x0D - GPPUB
	Wire.endTransmission();
	//clear out any interrupts that may be showing.
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x11);  //0x11 - INTCAPB
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	Wire.read();

}

void set_mcp_pin(uchar pin, int state)
{
	uchar lSetState=setState;
	
	//set the state and write it out
	lSetState=(S_PIN_MASK << pin | S_PIN_MASK >> sizeof(uchar)*8-pin) & lSetState|state<<pin;
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x12);  //0x12 - GPIOA
	Wire.write(lSetState);
	Wire.endTransmission();
	setState=lSetState;
}

void set_mcp_all(int state)
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x12);  //0x12 - GPIOA
	if(state)
	{
		Wire.write(0xFF);
	}
	else
	{
		Wire.write(0x00);
	}
	Wire.endTransmission();
}

uchar read_mcp_reg(uchar readReg)
{
	uchar retVal=0;
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(readReg);
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	retVal=Wire.read();//may need a cast here.
	return retVal;
}

void set_mcp_reg(uchar writeReg,uchar value)
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(writeReg);
	Wire.write(value);
	Wire.endTransmission();
}

void setRGB_led(uchar red, uchar green, uchar blue)
{
	analogWrite(ARD_STAT_RED,red);
	stateSpace.redVal=red;
	analogWrite(ARD_STAT_GREEN,green);
	stateSpace.greenVal=green;
	analogWrite(ARD_STAT_BLUE,blue);
	stateSpace.blueVal=blue;
}

void keypressInterrupt()
{
	//change this to handle waking up.
	readNeeded=1;
	digitalWrite(ARD_SEND_LED,readNeeded);
}

void process_state()
{
	if(setState!=oldSetState)
	{
		//if setState changed, then that implies that a button was pushed, 
		//act accordingly.

		if(setState & 0x20)
		{
			//send button pressed, clear out all lights
			//need to make this conditional, if there is data to send.  Also need
			//to add the code that will support multiple presses on the send button
			//triggering a connect request for the xbee.
			if(!(setState & 0xDF) && millis()<=lastInteractTime+SETUP_TIMEOUT)
			{
				//no other buttons were active, and press was fast enough see if
				//setup procedure should be entered
				if(++sendPressCount >= 3)
				{
					//do the setup here
				}
			}
			else if(!(setState & 0xDF))
			{
				//no other buttons were active but the previous presses didn't 
				//come fast enough.  Restart the count
				sendPressCount=1;
			}
			uchar sendRetval=0;
			setRGB_led(0,0,255);  //set to blue to indicate that we're sending
			stateSpace.wetState=0;
			stateSpace.wetVal=0;
			stateSpace.dirtyState=0;
			stateSpace.dirtyVal=0;
			stateSpace.feedState=0;
			stateSpace.feedVal=0;
			stateSpace.sleepState=0;
			stateSpace.sleepVal=0;
			stateSpace.wakeState=0;
			stateSpace.wakeVal=0;
			stateSpace.sendState=0;
			stateSpace.sendVal=0;

			set_mcp_reg(0x12,0); //gpio A
			digitalWrite(ARD_SEND_LED,LOW);

			set_canSleep(0); //not allowed to sleep while sending data

			for(int i=0;i<MAX_RETRIES && !sendRetVal;++i)
			{
				sendRetVal=send_data();
			}

			if(!sendRetVal)
			{
				//if after retries sendRetVal is still false, store the data
				//and show the failed send animation.

			}
			else
			{
				//no problems sending.  show the succesful send animation.
			}

			setState=0;
			sendPressCount=0;
		}
		else if(setState & 0x1F)
		{
			//any other buttons are active.
			//this means we can reset the time of last interaction and clear
			//any warning animation states that may have been running.
			stateSpace.wetState=0;
			stateSpace.wetVal=setState & ~S_PIN_MASK ? 255:0;
			stateSpace.dirtyState=0;
			stateSpace.dirtyVal=setState & ~S_PIN_MASK<<1 ? 255:0;
			stateSpace.feedState=0;
			stateSpace.feedVal=setState & ~S_PIN_MASK<<2 ? 255:0;
			stateSpace.sleepState=0;
			stateSpace.sleepVal=setState & ~S_PIN_MASK<<3 ? 255:0;
			stateSpace.wakeState=0;
			stateSpace.wakeVal=setState & ~S_PIN_MASK<<4 ? 255:0;
			stateSpace.sendState=stateSpace.sendState ? stateSpace.sendState : 1;
			set_mcp_reg(0x12, setState & 0x1F); //gpio a
			set_canSleep(0);  //running the send pending animation
		}
		else if(!state)
		{
			//this implies that the last active button was pressed.  Shutdown any 
			//buttons and stop any running animations.
			setRGB_led(0,0,0);
			stateSpace.wetState=0;
			stateSpace.wetVal=0;
			stateSpace.dirtyState=0;
			stateSpace.dirtyVal=0;
			stateSpace.feedState=0;
			stateSpace.feedVal=0;
			stateSpace.sleepState=0;
			stateSpace.sleepVal=0;
			stateSpace.wakeState=0;
			stateSpace.wakeVal=0;
			stateSpace.sendState=0;
			stateSpace.sendVal=0;

			digitalWrite(ARD_SEND_LED,LOW);
			set_mcp_reg(0x12,LOW);//gpio a
			set_canSleep(1); //no running animations or data being sent
		}
		oldSetState=setState;
		lastInteractTime=millis();
	}
	else if(state)
	{
		//no change in state, need to check if one of the timeouts has expired.
		unsigned long currTime=millis();
		if(currTime >= lastInteractTime + WARN_TIMEOUT && currTime < lastInteractTime + RESET_TIMEOUT)
		{
			//start up the animations for active buttons that aren't already set
			//to animate.
			if(setState & ~S_PIN_MASK && !stateSpace.wetState)
				stateSpace.wetState=1;
			if(setState & ~S_PIN_MASK<<1 && !stateSpace.dirtyState)
				stateSpace.dirtyState=1;
			if(setState & ~S_PIN_MASK<<2 && !stateSpace.feedState)
				stateSpace.feedState=1;
			if(setState & ~S_PIN_MASK<<3 && !stateSpace.sleepState)
				stateSpace.sleepState=1;
			if(setState & ~S_PIN_MASK<<4 && !stateSpace.wakeState)
				stateSpace.wakeState=1;
			set_canSleep(0); //running the time out warning animation.
		}
		else if(currTime >= lastInteractTime + RESET_TIMEOUT)
		{
			//clear out the state, reset the lights and update reset timer.
			lastInteractTime=millis();
			stateSpace.wetState=0;
			stateSpace.wetVal=0;
			stateSpace.dirtyState=0;
			stateSpace.dirtyVal=0;
			stateSpace.feedState=0;
			stateSpace.feedVal=0;
			stateSpace.sleepState=0;
			stateSpace.sleepVal=0;
			stateSpace.wakeState=0;
			stateSpace.wakeVal=0;
			stateSpace.sendState=0;
			stateSpace.sendVal=0;

			set_mcp_reg(0x12,0); //gpioa
			digitalWrite(ARD_SEND_LED,LOW);
			setState=0;
			set_canSleep(1); //no running animations and no data being sent
		}
	}
	updateAnimations();
}

void updateAnimations()
{
	if(stateSpace.sendState)
	{
		updateSendAnimation();
		set_canSleep(0);
	}
	if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
		stateSpace.sleepState || stateSpace.wakeState)
	{
		updateDataAnimation();
		set_canSleep(0);
	}
	if(stateSpace.rgbState)
	{
		updateRGBAnimation();
		set_canSleep(0);
	}
}


void updateSendAnimation()
{
	analogWrite(ARD_SEND_LED,stateSpace.sendVal); //make this conditional?  try running as is and then decide
	if(millis() >= stateSpace.sendUpTime)
	{
		switch(stateSpace.sendState)
		{
		case 1:
			//led is rising or on.
			stateSpace.sendVal+=5;
			stateSpace.sendUpTime=millis()+19;
			if(stateSpace.sendVal==255)
			{
				stateSpace.sendState=2;
				stateSpace.sendUpTime=millis()+500;//linger on full on for just a bit.
			}
			break;
		case 2:
			//led is falling or off.
			stateSpace.sendVal-=5;
			stateSpace.sendUpTime=millis()+30;  //play with this until effect is pleasing
			if(stateSpace.sendVal==0)
			{
				stateSpace.sendState=1;
				stateSpace.sendUpTime=millis()+200;  //linger just a bit.  again, tweak until pleasing.
			}
			break;
		default:
			//unknown animation state, stop the animation.
			stateSpace.sendState=0;
			break;
		}
	}
}

void updateDataAnimation()
{
Serial.println("would update data animation!");
}

void updateRGBAnimation()
{
	//temporary function body to replace testing code in loop().
unsigned long animStartTime=millis();
	if(millis() >= stateSpace.rgbUpTime)
	{
		switch(stateSpace.rgbState)
		{
		case 1:
			//full red, linger
			setRGB_led(255,0,0);
			stateSpace.rgbUpTime=millis()+1000;
			stateSpace.rgbState=2;
			break;
		case 2:
			//Red to green, turning green on
			setRGB_led(stateSpace.redVal,stateSpace.greenVal,0);
			stateSpace.greenVal+=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.greenVal==255)
			{
				stateSpace.rgbState=3;
			}
			break;
		case 3:
			//Red to green, turning red off
			setRGB_led(stateSpace.redVal,stateSpace.greenVal,0);
			stateSpace.redVal-=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.redVal==0)
			{
				stateSpace.rgbState=4;
			}
			break;
		case 4:
			//full green, linger
			setRGB_led(0,255,0);
			stateSpace.rgbUpTime=millis()+1000;
			stateSpace.rgbState=5;
			break;
		case 5:
			//green to blue, turning blue on
			setRGB_led(0,stateSpace.greenVal,stateSpace.blueVal);
			stateSpace.blueVal+=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.blueVal==255)
			{
				stateSpace.rgbState=6;
			}
			break;
		case 6:
			//green to blue, turning green off
			setRGB_led(0,stateSpace.greenVal,stateSpace.blueVal);
			stateSpace.greenVal-=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.greenVal==0)
			{
				stateSpace.rgbState=7;
			}
			break;
		case 7:
			//full blue, linger
			setRGB_led(0,0,255);
			stateSpace.rgbUpTime=millis()+1000;
			stateSpace.rgbState=8;
			break;
		case 8:
			//blue to red, turning red on
			setRGB_led(stateSpace.redVal,0,stateSpace.blueVal);
			stateSpace.redVal+=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.redVal==255)
			{
				stateSpace.rgbState=9;
			}
			break;
		case 9:
			//blue to red, turning blue off
			setRGB_led(stateSpace.redVal,0,stateSpace.blueVal);
			stateSpace.blueVal-=5;
			stateSpace.rgbUpTime=millis()+50;
			if(stateSpace.blueVal==0)
			{
				stateSpace.rgbState=1;
			}
			break;
		default:
			//unknown animation state, end the animation.
			stateSpace.rgbState=0;
			break;
		}//end state switch
	}//end animation timeout if
}//end updateRGBAnimation()

uchar set_canSleep(uchar newVal)
{
	uchar sregBack=SREG;
	noInterrupts();
	canSleep=newVal;
	SREG=sregBack;
	return canSleep;
}

uchar send_data()
{
	//will eventually send the data.  For the moment this is being used to test
	//the rtc module.
	uchar seconds;
	uchar minutes;
	uchar hours;
	uchar dayOfWeek;
	uchar dayOfMonth;
	uchar month;
	uchar year;
	uchar config;

	Wire.beginTransmission(RTC_ADDR);
	Wire.write(0x00);
	Wire.endTransmission();
	Wire.requestFrom(RTC_ADDR,8);//want to see the time registers and current configuration.
	seconds=Wire.read();
	minutes=Wire.read();
	hours=Wire.read();
	dayOfWeek=Wire.read();
	dayOfMonth=Wire.read();
	month=Wire.read();
	year=Wire.read();
	config=Wire.read();

	Serial.print("Seconds: ");
	Serial.println(seconds);
	Serial.print("Minutes: ");
	Serial.println(minutes);
	Serial.print("Hours: ");
	Serial.println(hours);
	Serial.print("Day of Week: ");
	Serial.println(dayOfWeek);
	Serial.print("Day of Month: ");
	Serial.println(dayOfMonth);
	Serial.print("Month: ");
	Serial.println(month);
	Serial.print("Year: ");
	Serial.println(year);
	Serial.print("Configuration Register: ");
	Serial.println(config);
}
