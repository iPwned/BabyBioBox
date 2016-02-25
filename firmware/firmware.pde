/*******************************************************************************
*firmware.pde
*
*Firmware for the BabyBioBox project
*******************************************************************************/
#include <Wire.h>
#include <EEPROM.h>

#define ARD_XB_CTS 4
#define ARD_XB_ON_SLEEP 6
#define ARD_MCP_INT 7
#define ARD_XB_SLEEP_REQ 8
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
	unsigned char wetVal;
	unsigned char dirtyVal;
	unsigned char feedVal;
	unsigned char sleepVal;
	unsigned char wakeVal;
	unsigned char sendVal;
	unsigned char redVal;
	unsigned char greenVal;
	unsigned char blueVal;
} ledStateSpace;


void init_mcp();
void set_mcp_pin(unsigned char pin, int state);
void set_mcp_all(int state);
unsigned char read_mcp_reg(unsigned char readReg);
void set_mcp_reg(unsigned char writeReg,unsigned char value);
void setRGB_led(unsigned char red, unsigned char green, unsigned char blue);
void keypressInterrupt();
void process_state();
void updateAnimations();
void updateSendAnimation();
void updateRGBAnimation();
unsigned char set_noSleep(unsigned char newVal);
unsigned char up_noSleep();
unsigned char down_noSleep();
unsigned char send_data();
unsigned char rtc_data_function();
unsigned char bcd_to_uchar(unsigned char bcdVal);
unsigned char uchar_to_bcd(unsigned char ucharVal);
unsigned char read_uchar_from_serial();
unsigned char provision_xbee();

ledStateSpace stateSpace;
//int state=HIGH;
//unsigned char testPin=0;
unsigned long lastInteractTime=0;
unsigned long lastReadTime=0;
int sendPressCount=0;
unsigned char setState=0;
unsigned char oldSetState=0;
unsigned char animState=0;
unsigned char lastReadState=0;
volatile unsigned char readNeeded=0;
volatile unsigned char noSleep=0; //till Brooklyn!  BROOKLYN!

void setup()
{
	pinMode(ARD_XB_CTS, INPUT);
	pinMode(ARD_XB_ON_SLEEP,INPUT);
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
		unsigned char readState=read_mcp_reg(0x13); //read gpio b
		if(readState!=lastReadState)
		{
			if(millis()-lastReadTime >= DEBOUNCE_WINDOW)
			{
				lastReadTime=millis();
				lastReadState=readState;
				setState= setState ^ readState; //first press to enable second press to clear
			}
		}
	//switching to active low interrupts /should/ obviate the need for the digitalRead.
	//readNeeded=digitalRead(MCP_INT_PIN);
	//digitalWrite(ARD_SEND_LED,readNeeded);
	process_state();
	if(!noSleep)
	{
		// attachInterrupt(digitalPinToInterrupt(ARD_MCP_INT),keypressInterrupt,LOW);
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

void set_mcp_pin(unsigned char pin, int state)
{
	unsigned char lSetState=setState;
	
	//set the state and write it out
	lSetState=(S_PIN_MASK << pin | S_PIN_MASK >> sizeof(unsigned char)*8-pin) & lSetState|state<<pin;
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

unsigned char read_mcp_reg(unsigned char readReg)
{
	unsigned char retVal=0;
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(readReg);
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	retVal=Wire.read();
	return retVal;
}

void set_mcp_reg(unsigned char writeReg,unsigned char value)
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(writeReg);
	Wire.write(value);
	Wire.endTransmission();
}

void setRGB_led(unsigned char red, unsigned char green, unsigned char blue)
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
	// readNeeded=1;
	// digitalWrite(ARD_SEND_LED,readNeeded);
}

void process_state()
{
	if(setState!=oldSetState)
	{
Serial.println("inside differing states");
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
			}//end send only and not timed out if
			else if(!(setState & 0xDF))
			{
				//no other buttons were active but the previous presses didn't 
				//come fast enough.  Restart the count
				sendPressCount=1;
			}//end send only and timed out if
			else
			{
				//account for any running animations which will be disabled
				if(stateSpace.sendState)
				{
					down_noSleep();
				}
				if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
					stateSpace.sleepState || stateSpace.wakeState)
				{
					down_noSleep();
				}

				unsigned char sendRetVal=0;
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

				//not allowed to sleep while sending data and running the send 
				//successful/failed animations
				up_noSleep(); 

				for(int i=0;i<MAX_RETRIES && !sendRetVal;++i)
				{
					//sendRetVal=send_data();
					sendRetVal=rtc_data_function();
				}

				if(!sendRetVal)
				{
					//if after retries sendRetVal is still false, store the data
					//and show the failed send animation.
					stateSpace.rgbState=10;
					//store info here
				}
				else
				{
					//no problems sending.  show the succesful send animation.
					stateSpace.rgbState=16;
				}

				sendPressCount=0;
			}//end send and others else
			setState=0;
		}//end send press if
		else if(setState & 0x1F)
		{
			//any other buttons are active.
			//this means we can reset the time of last interaction and clear
			//any warning animation states that may have been running.
			if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
				stateSpace.sleepState || stateSpace.wakeState)
			{
				down_noSleep(); //the time out warning animation would have raised the count
			}
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
			if(!stateSpace.sendState)
			{
				//if the send button isn't already animated turn on the animation
				//and make unelligble for sleep
				up_noSleep();
			}
			stateSpace.sendState=stateSpace.sendState ? stateSpace.sendState : 1;
			set_mcp_reg(0x12, setState & 0x1F); //gpio a
		}//end other button press else if
		else if(!setState)
		{
			//this implies that the last active button was pressed.  Shutdown any 
			//buttons and stop any running button animations.
			if(stateSpace.sendState)
			{
				down_noSleep();
			}
			if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
				stateSpace.sleepState || stateSpace.wakeState)
			{
				down_noSleep();
			}
			//allow any rgb animations to continue.
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
		}//end last button toggle else if
		oldSetState=setState;
		lastInteractTime=millis();
	}//end state change if
	else if(setState)
	{
		//no change in state, need to check if one of the timeouts has expired.
		unsigned long currTime=millis();
		if(currTime >= lastInteractTime + WARN_TIMEOUT && currTime < lastInteractTime + RESET_TIMEOUT)
		{
			//start up the animations for active buttons that aren't already set
			//to animate.
			if(!stateSpace.wetState && !stateSpace.dirtyState && !stateSpace.feedState &&
				!stateSpace.sleepState && !stateSpace.wetState)
			{
				//this is the first time through, none of the buttons have been animated
				//yet, so the sleep lockout needs to be set
				up_noSleep();
			}
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
		}//end time out warning if
		else if(currTime >= lastInteractTime + RESET_TIMEOUT)
		{
			//clear out the state, reset the lights and update reset timer.
			if(stateSpace.sendState)
			{
				down_noSleep();
			}
			if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
				stateSpace.sleepState || stateSpace.wakeState)
			{
				down_noSleep();
			}

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
		}//end time out else if
	}//end idle state else if
	updateAnimations();
}//end process_state

void updateAnimations()
{
	if(stateSpace.sendState)
	{
		updateSendAnimation();
	}
	if(stateSpace.wetState || stateSpace.dirtyState || stateSpace.feedState ||
		stateSpace.sleepState || stateSpace.wakeState)
	{
		updateDataAnimation();
	}
	if(stateSpace.rgbState)
	{
		updateRGBAnimation();
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
			down_noSleep();
			stateSpace.sendState=0;
			break;
		}
	}
}

void updateDataAnimation()
{
	unsigned long currTime=millis();
	if(currTime>=stateSpace.wetUpTime || currTime>=stateSpace.dirtyUpTime ||
		currTime >=stateSpace.feedUpTime || currTime>=stateSpace.sleepUpTime ||
		currTime>=stateSpace.wakeUpTime)
	{
		unsigned char sendVal=0;
		//this assumes that all data lights that are animated have the same value
		if(stateSpace.wetState==1 || stateSpace.dirtyState==1 || stateSpace.feedState==1 ||
			stateSpace.wakeState==1 || stateSpace.sleepState==1)
		{
			if(stateSpace.wetState)
			{
				stateSpace.wetState=2;
				stateSpace.wetVal=255;
				sendVal|=1;
			}
			if(stateSpace.dirtyState)
			{
				stateSpace.dirtyState=2;
				stateSpace.dirtyVal=255;
				sendVal|=2;
			}
			if(stateSpace.feedState)
			{
				stateSpace.feedState=2;
				stateSpace.feedVal=255;
				sendVal|=4;
			}
			if(stateSpace.sleepState)
			{
				stateSpace.sleepState=2;
				stateSpace.sleepVal=255;
				sendVal|=8;
			}
			if(stateSpace.wakeState)
			{
				stateSpace.wakeState=2;
				stateSpace.wakeVal=255;
				sendVal|=16;
			}
			stateSpace.wetUpTime=currTime+400;
			stateSpace.dirtyUpTime=currTime+400;
			stateSpace.feedUpTime=currTime+400;
			stateSpace.sleepUpTime=currTime+400;
			stateSpace.wakeUpTime=currTime+400;
			set_mcp_reg(0x12,sendVal);
		}//end state 1 if
		else if(stateSpace.wetState==2 || stateSpace.dirtyState==2 || stateSpace.feedState==2 ||
			stateSpace.wakeState==2 || stateSpace.sleepState==2)
		{
			if(stateSpace.wetState)
			{
				stateSpace.wetState=1;
				stateSpace.wetVal=0;
				sendVal&=0xFE;
			}
			if(stateSpace.dirtyState)
			{
				stateSpace.dirtyState=1;
				stateSpace.dirtyVal=0;
				sendVal&=0xFD;
			}
			if(stateSpace.feedState)
			{
				stateSpace.feedState=1;
				stateSpace.feedVal=0;
				sendVal&=0xFB;
			}
			if(stateSpace.sleepState)
			{
				stateSpace.sleepState=1;
				stateSpace.sleepVal=0;
				sendVal&=0xF7;
			}
			if(stateSpace.wakeState)
			{
				stateSpace.wakeState=1;
				stateSpace.wakeVal=0;
				sendVal&=0xEF;
			}
			stateSpace.wetUpTime=currTime+400;
			stateSpace.dirtyUpTime=currTime+400;
			stateSpace.feedUpTime=currTime+400;
			stateSpace.sleepUpTime=currTime+400;
			stateSpace.wakeUpTime=currTime+400;
			set_mcp_reg(0x12,sendVal);
		}	
	}//end data update timer if
}//end updateDataAnimation

void updateRGBAnimation()
{
	unsigned long animStartTime=millis();

	//State 1 starts a color cycle animation on the led and runs through state
	//	9 before repeating
	//State 10 is the send data failed animation.  Alternates between full blue
	//	and full red three times before returning to state 0.
	//State 16 if the send data succeeded animation.  Alternates between full 
	//	blue and full green three times before returning to state 0.
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
		case 10:
		case 12:
		case 14:
		case 16:
		case 18:
		case 20:
			//send, three full blue passes
			setRGB_led(0,0,255);
			stateSpace.rgbUpTime=millis()+333;
			++stateSpace.rgbState;
			break;
		case 11:
		case 13:
			//failed send, first and second full red
			setRGB_led(255,0,0);
			stateSpace.rgbUpTime=millis()+333;
			++stateSpace.rgbState;
			break;
		case 15:
			//failed send, third (final) full red
			setRGB_led(255,0,0);
			stateSpace.rgbUpTime=millis()+333;
			stateSpace.rgbState=255;
			break;
		case 17:
		case 19:
			//successful send, first and second full green
			setRGB_led(0,255,0);
			stateSpace.rgbUpTime=millis()+333;
			++stateSpace.rgbState;
			break;
		case 21:
			//successful send, third (final) full green
			setRGB_led(0,255,0);
			stateSpace.rgbUpTime=millis()+333;
			stateSpace.rgbState=255;
			break;
		case 255:
			//end animation state
		default:
			//unknown animation state, end the animation.
			stateSpace.rgbState=0;
			setRGB_led(0,0,0);
			down_noSleep();//no longer animating, don't prevent sleep on our account.
			break;
		}//end state switch
	}//end animation timeout if
}//end updateRGBAnimation()

unsigned char set_noSleep(unsigned char newVal)
{
	unsigned char sregBack=SREG;
	noInterrupts();
	noSleep=newVal;
	SREG=sregBack;
	return noSleep;
}

unsigned char up_noSleep()
{
	unsigned char sregBack=SREG;
	noInterrupts();
	++noSleep;
	SREG=sregBack;
	return noSleep;
}

unsigned char down_noSleep()
{
	unsigned char sregBack=SREG;
	noInterrupts();
	--noSleep;
	noSleep=noSleep<0?0:noSleep;
	SREG=sregBack;
	return noSleep;
}

unsigned char send_data()
{
	unsigned char seconds;
	unsigned char minutes;
	unsigned char hours;
	unsigned char dayOfWeek;
	unsigned char dayOfMonth;
	unsigned char month;
	unsigned char year;

	Wire.beginTransmission(RTC_ADDR);
	Wire.write(0x00);
	Wire.endTransmission();
	Wire.requestFrom(RTC_ADDR,7);
	seconds=Wire.read();
	minutes=Wire.read();
	hours=Wire.read();
	dayOfWeek=Wire.read();
	dayOfMonth=Wire.read();
	month=Wire.read();
	year=Wire.read();

	hours=hours&0x7F;

	//gather data from the state space
	//build post string
	//wake up radio
	//send post string
	//check status of send
	//sleep radio
	//return send status

	return 1;
}

unsigned char rtc_data_function()
{
	unsigned char seconds;
	unsigned char minutes;
	unsigned char hours;
	unsigned char dayOfWeek;
	unsigned char dayOfMonth;
	unsigned char month;
	unsigned char year;
	unsigned char config;

	unsigned char serialChar;

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

	Serial.println("Read a time of");
	hours=hours & 0x40 ? (hours & 0x3F) : (hours & 0x7F);
	Serial.print(uchar_to_bcd(hours));
	Serial.print(":");
	Serial.print(uchar_to_bcd(minutes));
	Serial.print(":");
	Serial.print(uchar_to_bcd(seconds));
	Serial.print(" ");
	Serial.print(uchar_to_bcd(month));
	Serial.print("/");
	Serial.print(uchar_to_bcd(dayOfMonth));
	Serial.print("/");
	Serial.println(uchar_to_bcd(year));
	Serial.print("Day of Week: ");
	Serial.println(uchar_to_bcd(dayOfWeek));
	Serial.print("Configuration Register: ");
	Serial.println(config);
	Serial.print("Edit config (y/n)?");
	if(Serial.available()>0)
	{
		serialChar=Serial.read();
	}
	if(serialChar=='y'||serialChar=='Y')
	{
		Serial.println("Enter new HOURS value: ");
		hours=uchar_to_bcd(read_uchar_from_serial());
		//want to use 24 hour time, so set the bits right for
		//that.
		hours=hours & 0xBF;

		Serial.println("Enter new MINUTES value: ");
		minutes=uchar_to_bcd(read_uchar_from_serial());

		Serial.println("Enter new SECONDS value: ");
		seconds=uchar_to_bcd(read_uchar_from_serial());

		Serial.println("Enter new MONTH value: ");
		month=uchar_to_bcd(read_uchar_from_serial());

		Serial.println("Enter new DAY OF MONTH value: ");
		dayOfMonth=uchar_to_bcd(read_uchar_from_serial());

		Serial.println("Enter new YEAR value: ");
		year=uchar_to_bcd(read_uchar_from_serial());

		Serial.println("Enter new DAY OF WEEK value: ");
		dayOfWeek=uchar_to_bcd(read_uchar_from_serial());
		
		Wire.beginTransmission(RTC_ADDR);
		Wire.write(0x00);
		Wire.write(seconds);
		Wire.write(minutes);
		Wire.write(hours);
		Wire.write(dayOfWeek);
		Wire.write(dayOfMonth);
		Wire.write(month);
		Wire.write(year);
		Wire.write(0x00);//don't need the square wave output
		Wire.endTransmission();
	}

	return 1;
}

unsigned char bcd_to_uchar(unsigned char bcdVal)
{
	unsigned char retVal=0;
	retVal=((bcdVal&0xF0)>>4)*10 + bcdVal&0x0F;
	return retVal;
}

unsigned char uchar_to_bcd(unsigned char ucharVal)
{
	//assumes that we're only working with 2 digit values
	unsigned char retVal=0;
	retVal=ucharVal/10<<4 | ucharVal%10;
	return retVal;
}

unsigned char read_uchar_from_serial()
{
	unsigned char serialChar;
	unsigned char retVal;
	serialChar=Serial.read();
	retVal=(serialChar-'0')*10;
	serialChar=Serial.read();
	retVal+=serialChar-'0';
	return retVal;
}

unsigned char xbee_init()
{
	char* destName;
	char destIP[16]={'\0'};
	int pos;
	unsigned char destNameLength;
	unsigned char retVal=0;

	destNameLength=EEPROM.read(0);
	destName=(char*)calloc(destNameLength+1,sizeof(char));

	for(pos=1;pos<=destNameLength;++pos)
	{
		destName[pos-1]=EEPROM.read(pos);
	}

	
	if(!xbee_enter_command_mode())
	{
		free(destName);
		return 0;
	}
	
	Serial1.println("atni BabyBioBox");
	xbee_check_command_response();
	pos=0;
	Serial1.print("atla ");
	Serial1.println(destName);
	while(Serial1.available())
	{
		destIP[pos]=Serial1.read();
		if(destIP[pos]=='E')
		{
			free(destName);
			return 0;
		}
		++pos;
	}
	free(destName);
	Serial1.print("atdl ");
	Serial1.println(destIP);
	if(!xbee_check_command_response()){return 0;}
	Serial1.println("atde 50");
	if(!xbee_check_command_response()){return 0;}
	Serial1.println("atsm 1");
	xbee_check_command_response();
	Serial1.println("atso 40");
	xbee_check_command_response();
	Serial1.println("atcn");
	xbee_check_command_response();
	return 1;
}

unsigned char xbee_provision()
{
	if(!xbee_enter_command_mode()){return 0;}
}

unsigned char xbee_check_command_response()
{
	unsigned char retVal=0;
	unsigned char responseChar;
	
	if(Serial1.available())
	{
		responseChar=Serial1.read();
	}
	if(responseChar=='O')
	{
		retVal=1;
	}
	while(Serial1.available())
	{
		Serial1.read();
	}
	return retVal;
}

unsigned char xbee_enter_command_mode()
{
	delay(1000);
	Serial1.print("+++");
	delay(1000);
	//xbee should now be in command mode.
	return xbee_check_command_response();
}
