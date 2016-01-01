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

#define S_PIN_MASK 0xFE
#define WARN_TIMEOUT 120000
#define RESET_TIMEOUT 150000
#define DEBOUNCE_WINDOW 100
//play with buttons and the scope to figure out how long the debounce window actually needs to be

typedef struct _ledStateSpace
{
	unsigned long wetUpTime;
	unsigned long dirtyUpTime;
	unsigned long feedUpTime;
	unsigned long sleepUpTime;
	unsigned long wakeUpTime;
	unsigned long sendUpTime;
	unsigned long redUpTime;
	unsigned long greenUpTime;
	unsigned long blueUpTime;
	unsigned int wetState;
	unsigned int dirtyState;
	unsigned int feedState;
	unsigned int sleepState;
	unsigned int wakeState;
	unsigned int sendState;
	unsigned int redState;
	unsigned int greenState;
	unsigned int blueState;
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

ledStateSpace stateSpace;
//int state=HIGH;
//unsigned char testPin=0;
unsigned long lastInteractTime=0;
unsigned char setState=0;
unsigned char oldSetState=0;
unsigned char animState=0;
volatile unsigned char readNeeded=0;

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
	stateSpace.redUpTime=0;
	stateSpace.greenUpTime=0;
	stateSpace.blueUpTime=0;
	stateSpace.wetState=0;
	stateSpace.dirtyState=0;
	stateSpace.feedState=0;
	stateSpace.sleepState=0;
	stateSpace.wakeState=0;
	stateSpace.sendState=0;
	stateSpace.redState=0;
	stateSpace.greenState=0;
	stateSpace.blueState=0;
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
	attachInterrupt(digitalPinToInterrupt(ARD_MCP_INT),keypressInterrupt,LOW);
}

void loop()
{
	setRGB_led(255, 255, 255);
	delay(300);
	setRGB_led(255, 0, 0);
	delay(300);
	setRGB_led(0, 255, 0);
	delay(300);
	setRGB_led(0, 0, 255);
	delay(300);

	//set_mcp_pin(testPin,state);
	//testPin=(testPin+1)%8;
	//if(testPin==0) state= ~state;

	if(readNeeded)
	{
		//debounce keys here?
		setState= setState ^ read_mcp_port(); //first press to enable second press to clear
		readNeeded=0;
	digitalWrite(ARD_SEND_LED,readNeeded);
	}
	//switching to active low interrupts /should/ obviate the need for the digitalRead.
	//readNeeded=digitalRead(MCP_INT_PIN);
	//digitalWrite(ARD_SEND_LED,readNeeded);
	process_state();
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

unsigned char read_mcp_port()
{
	unsigned char retVal=0;
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x11);  //0x11 - INTCAPB
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	retVal=Wire.read();//may need a cast here.
	return retVal;
}

void set_mcp_port(unsigned char value)
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x12);  //0x12 - GPIOA
	Wire.write(value);
	Wire.endTransmission();
}

void setRGB_led(unsigned char red, unsigned char green, unsigned char blue)
{

	analogWrite(ARD_STAT_RED,red);
	analogWrite(ARD_STAT_GREEN,green);
	analogWrite(ARD_STAT_BLUE,blue);
}

/* Not needed if I move forward with the datastructure idea
void set_anim_state(unsigned char pin, int state)
{
	unsigned char lAnimState=animState;
	lAnimState=(S_PIN_MASK<<pin | S_PIN_MASK>>sizeof(unsigned char)*8-pin)&lAnimState|state<<pin;
	animState=lAnimState;
}
*/

void keypressInterrupt()
{
	readNeeded=1;
	digitalWrite(ARD_SEND_LED,readNeeded);
}

void process_state()
{
	unsigned char mcpSendState=0;
	if(setState!=oldSetState)
	{
		//if setState changed, then that implies that a button was pushed, 
		//act accordingly.

		if(setState & 0x20)
		{
			//send button pressed, clear out all lights
			lastInteractTime=millis();
			ledStateSpace.wetState=0;
			ledStateSpace.wetVal=0;
			ledStateSpace.dirtyState=0;
			ledStateSpace.dirtyVal=0;
			ledStateSpace.feedState=0;
			ledStateSpace.feedVal=0;
			ledStateSpace.sleepState=0;
			ledStateSpace.sleepVal=0;
			ledStateSpace.wakeState=0;
			ledStateSpace.wakeVal=0;
			ledStateSpace.sendState=0;
			ledStateSpace.sendVal=0;

			set_mcp_port(0);
			digitalWrite(ARD_SEND_LED,LOW);

			//do the send here.

			setState=0;
		}
		else if(setState & 0x1F)
		{
			//any other buttons are active.
			//this means we can reset the time of last interaction and clear
			//any warning animation states that may have been running.
			lastInteractTime=millis();
			ledStateSpace.wetState=0;
			ledStateSpace.wetVal=setState & ~S_PIN_MASK ? 255:0;
			ledStateSpace.dirtyState=0;
			ledStateSpace.dirtyVal=setState & ~S_PIN_MASK<<1 ? 255:0;
			ledStateSpace.feedState=0;
			ledStateSpace.feedVal=setState & ~S_PIN_MASK<<2 ? 255:0;
			ledStateSpace.sleepState=0;
			ledStateSpace.sleepVal=setState & ~S_PIN_MASK<<3 ? 255:0;
			ledStateSpace.wakeState=0;
			ledStateSpace.wakeVal=setState & ~S_PIN_MASK<<4 ? 255:0;
			set_mcp_port(setState & 0x1F);
		}
			
	}
	else //if setState?  Don't really care about setting up animations and reset timers if there's no state right?
	{
		//no change in state, need to check if one of the timeouts has expired.
		unsigned long currTime=millis();
		if(currTime >= lastInteractTime + WARN_TIMEOUT && currTime < lastInteractTime + RESET_TIMEOUT)
		{
			//start up the animations for active buttons that aren't already set
			//to animate.
			if(setState & ~S_PIN_MASK && !ledStateSpace.wetState)
				ledStateSpace.wetState=1;
			if(setState & ~S_PIN_MASK<<1 && !ledStateSpace.dirtyState)
				ledStateSpace.dirtyState=1;
			if(setState & ~S_PIN_MASK<<2 && !ledStateSpace.feedState)
				ledStateSpace.feedState=1;
			if(setState & ~S_PIN_MASK<<3 && !ledStateSpace.sleepState)
				ledStateSpace.sleepState=1;
			if(setState & ~S_PIN_MASK<<4 && !ledStateSpace.wakeState)
				ledStateSpace.wakeState=1;
		}
		else if(currTime <= lastInteractTime + RESET_TIMEOUT)
		{
			//clear out the state, reset the lights and update reset timer.
			lastInteractTime=millis();
			ledStateSpace.wetState=0;
			ledStateSpace.wetVal=0;
			ledStateSpace.dirtyState=0;
			ledStateSpace.dirtyVal=0;
			ledStateSpace.feedState=0;
			ledStateSpace.feedVal=0;
			ledStateSpace.sleepState=0;
			ledStateSpace.sleepVal=0;
			ledStateSpace.wakeState=0;
			ledStateSpace.wakeVal=0;
			ledStateSpace.sendState=0;
			ledStateSpace.sendVal=0;

			set_mcp_port(0);
			digitalWrite(ARD_SEND_LED,LOW);
			setState=0;
		}
	}
	updateAnimations();
	oldSetState=setState;
}

void updateAnimations()
{

}
