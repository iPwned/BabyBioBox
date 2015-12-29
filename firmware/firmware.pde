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

void init_mcp();
void set_mcp_pin(unsigned char pin, int state);
void set_mcp_all(int state);

int state=LOW;

void setup()
{
	pinMode(ARD_CTS, INPUT);
	pinMode(ARD_ON_SLEEP,INPUT);
	pinMode(ARD_STAT_RED,OUTPUT);
	pinMode(ARD_STAT_GREEN,OUTPUT);
	pinMode(ARD_STAT_BLUE,OUTPUT);
	pinMode(ARD_SEND_LED,OUTPUT);

	Serial.begin(9600);
	Serial1.begin(9600);
	Wire.begin();
	init_mcp();
	//register interrupts here
}

void loop()
{
	digitalWrite(ARD_SEND_LED,HIGH);
	setRGB_led((unsigned char) 255, (unsigned char) 255, (unsigned char)255);
	delay(300);
	setRGB_led((unsigned char) 255, (unsigned char) 0, (unsigned char) 0);
	delay(300);
	setRGB_led((unsigned char) 0, (unsigned char) 255, (unsigned char) 0);
	delay(300);
	setRGB_led((unsigned char) 0, (unsigned char) 0, (unsigned char) 255);
	set_mcp_pin(0,state);
	state=~state;
	//clear the interupt for testing purposes.
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x11);
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	Wire.read();
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
	unsigned char setState=0;
	//get the current state.
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x15); //set the address to GPIOB
	Wire.endTransmission();
	Wire.requestFrom(MCP_ADDR,1);
	setState=(unsigned char)Wire.read();
	
	//set the state and write it out
Serial.print("Initial set state: ");
Serial.println(setState);
Serial.print("Pin: ");
Serial.println(sizeof(unsigned char)-pin);
	// setState=((unsigned char)0xFE << pin |((unsigned char)0xFE>>sizeof(unsigned char)-pin));
	// setState=(unsigned char)0xFE << pin | (unsigned char)0xFE >> sizeof(unsigned char)-pin;
	setState=(unsigned char)0xFE >> sizeof(unsigned char)*8-pin;
Serial.print("Modified set state: ");
Serial.println(setState);
	Wire.beginTransmission(MCP_ADDR);
	Wire.write(0x12);
	Wire.write(setState);
	Wire.endTransmission();
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

void setRGB_led(unsigned char red, unsigned char green, unsigned char blue)
{

	analogWrite(ARD_STAT_RED,red);
	analogWrite(ARD_STAT_GREEN,green);
	analogWrite(ARD_STAT_BLUE,blue);
}