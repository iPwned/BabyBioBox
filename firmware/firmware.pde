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
#define MCP_INT_PIN 7
/*Check schematic.  Valid options are 0-3 and 7*/

#define S_PIN_MASK 0xFE


typedef struct _ledValues
{
	unsigned char wetButton;
	unsigned char dirtyButton;
	unsigned char feedButton;
	unsigned char sleepButton;
	unsigned char wakeButton;
	unsigned char sendButton;
	unsigned char statusRed;
	unsigned char statusGreen;
	unsigned char statusBlue;
} ledValues;

void init_mcp();
void set_mcp_pin(unsigned char pin, int state);
void set_mcp_all(int state);

int state=HIGH;
unsigned char testPin=0;
unsigned char setState=0;
unsigned char animState=0;
volatile unsigned char readNeeded=0;
ledValues currLightVals;

void setup()
{
	pinMode(ARD_CTS, INPUT);
	pinMode(ARD_ON_SLEEP,INPUT);
	pinMode(ARD_STAT_RED,OUTPUT);
	pinMode(ARD_STAT_GREEN,OUTPUT);
	pinMode(ARD_STAT_BLUE,OUTPUT);
	pinMode(ARD_SEND_LED,OUTPUT);
	pinMode(MCP_INT_PIN,INPUT);

	currLightVals.wetButton=0;
	currLightVals.dirtyButton=0;
	currLightVals.feedButton=0;
	currLightVals.sleepButton=0;
	currLightVals.wakeButton=0;
	currLightVals.sendButton=0;
	currLightVals.statusRed=0;
	currLightVals.statusGreen=0;
	currLightVals.statusBlue=0;

	Serial.begin(9600);
	Serial1.begin(9600);
	Wire.begin();
	init_mcp();
	attachInterrupt(digitalPinToInterrupt(MCP_INT_PIN),keypressInterrupt,RISING);
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

	set_mcp_pin(testPin,state);
	testPin=(testPin+1)%8;
	if(testPin==0) state= ~state;

	if(readNeeded)
	{
		//debounce keys here?
		readNeeded=0;
		read_mcp_port();
	digitalWrite(ARD_SEND_LED,readNeeded);
	}
	readNeeded=digitalRead(MCP_INT_PIN);
	digitalWrite(ARD_SEND_LED,readNeeded);
	delay(300);
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
	Wire.write(0x02);  //0x0A - ICONN
	Wire.write(0x02);  //0x0B - ICONN
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
	Wire.write(0x12);
	Wire.write(lSetState);
	Wire.endTransmission();
	setState=lSetState;
}

void set_mcp_all(int state)
{
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x12);
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

void setRGB_led(unsigned char red, unsigned char green, unsigned char blue)
{

	analogWrite(ARD_STAT_RED,red);
	analogWrite(ARD_STAT_GREEN,green);
	analogWrite(ARD_STAT_BLUE,blue);
}

void set_anim_state(unsigned char pin, int state)
{
	unsigned char lAnimState=animState;
	lAnimState=(S_PIN_MASK<<pin | S_PIN_MASK>>sizeof(unsigned char)*8-pin)&lAnimState|state<<pin;
	animState=lAnimState;
}

void keypressInterrupt()
{
	readNeeded=1;
	digitalWrite(ARD_SEND_LED,readNeeded);
}
