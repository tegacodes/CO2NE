// 1.2 release May 2009
// - added location specific parsing 
// to account for differences in UK & UK xml
// - also added auto-sensing for Current Cost Classic
// - finally remembered to make temperature a float to
// take account of the accuracy of the temp measurement

import eeml.*;
import processing.serial.*;

Serial myPort; 
int val;
String buffer = "";
String message = "";
int startPos;
int endPos;
XML xml;
int[] watts;
float temperature = 0;
DataOut dOut;
int updateInterval = 10; // seconds
double lastUpdate;
double lastMessage; 
int numberOfClamps;
String debugMessage = "";
PFont font;
String pachubeURL;
String pachubeAPI = "";
int serialDevice;
boolean foundCC = false;
String loadPath = "CurrentCostPreferences.txt";
PImage pachube;
int historySize = 210;

int[][] historicValues;

String this_model;
String this_area;

boolean modelVerified = false;

boolean datastreamsSet = false;

int[] serial_speed = { 
  57600, 9600 };

int this_serial_speed;
String unit = "";

PrintWriter output;

void setup() 
{
  size(250, 470);

  frameRate(2);

  watts = new int[9];
  String[] fontList = PFont.list();
  println(fontList);
  font = createFont("Candara", 32);
  textFont(font);
  loadPreferences();
  this_model = "";
  this_area = "";

  if (!pachubeAPI.equals("")){

    try {

      this_serial_speed = 0;

      setupSerial(serial_speed[this_serial_speed]);
      setupPachube();

      fill(255,255,255);

      debugMessage = "CurrentCost\n\nNo info received yet\nDevice selected: \n"+Serial.list()[serialDevice]+"\n\nClamps: "+numberOfClamps;

    }
    catch (Exception e){
      println("There was a problem starting up. Was the serial port detected?" + e);
    }

    smooth();
  }
output = createWriter("data.txt");//create file in sketch directory

  //pachube = loadImage("pachube.png");
}

void draw()
{

  float energyStatus = constrain(watts[0]/10, 0, 255);
  background(energyStatus, 255-energyStatus, 0);

  while (myPort.available() > 0) {

    if (!modelVerified) {


    }

    String inBuffer = myPort.readString();   
    if (inBuffer != null) {
      buffer += inBuffer;

      println(buffer);

      if (!modelVerified) {    

        boolean nonsenseXML = false;

        for (int i = 0; i < buffer.length(); i++){
          int b = (int)buffer.charAt(i);
          if (b > 255){
            nonsenseXML = true;
          } 
        }

        if (nonsenseXML){
          this_serial_speed = (this_serial_speed+1)%2;
          println("Received nonsensical XML... trying new serial port speed: "+serial_speed[this_serial_speed]);
          myPort.clear();
          myPort.stop();
          setupSerial(serial_speed[this_serial_speed]);
          debugMessage = "Trying new serial port \nspeed: " +serial_speed[this_serial_speed] + ". Please wait\na few seconds";
          lastUpdate = millis();
        }
      } 




      startPos = buffer.indexOf("<msg>");
      endPos = buffer.indexOf("</msg>");

      if ((startPos >=0) && (endPos > 0)){
        if (endPos > startPos){              
          // println("Found full message from CurrentCost");
          // println(buffer + "---" + startPos + "---" + endPos);

          message = buffer.substring(startPos, endPos);
          buffer = "";
          currentCostParse(message);
          foundCC = true;

          modelVerified = true;
          lastMessage = millis();

        } 
        else {                
          buffer = buffer.substring(startPos, buffer.length());
        }
      }



    }
  } 

  if ((millis() - lastUpdate) > updateInterval * 1000){
    if (modelVerified){
      pachube();
      lastUpdate = millis();
    }
  }

  if (millis() < lastUpdate) lastUpdate = millis();


  fill(255,255,255);

  textSize(18);
  text(debugMessage, 30, 30);

  textFont(font, 12);
  text("Time to Pachube update: " + (int)(updateInterval - (millis()-lastUpdate)/1000) + " secs", 30, 255);


  rect(-1,260,width+2,height-260);

  drawPachube();
  drawGraph();
}

void currentCostParse(String m){

  if ((m.indexOf("<hist") < 0) || (serial_speed[this_serial_speed] == 9600)){

    try{

      debugMessage = "CurrentCost\n\nPower: \n";

      if (m.indexOf("<tmprF") < 0){
        this_area = "UK";   
      } 
      else {
        this_area = "US";   
      }

      for (int i = 0; i < numberOfClamps; i++){
        watts[i] = int(parseDoubleElement(m,"ch"+(i+1),"watts"));
        
        debugMessage += ((i+1) + " - " + watts[i] + " W\n");
        arrayCopy(historicValues[i], 1, historicValues[i], 0, historySize-1);
        historicValues[i][historySize-1] = watts[i];
      }

      debugMessage += "\nTemperature: ";


      if (this_area.equals("UK")){
        temperature = float(parseSingleElement(m,"tmpr"));
        unit = "C";
      } 
      else {
        temperature = float(parseSingleElement(m,"tmprF"));
        unit = "F";
      }
      debugMessage += (temperature + "° "+unit+"\n");

      println(debugMessage);

      if (!datastreamsSet){
        setupDatastreams();   
      }



    }

    catch (Exception e){

      println("There was a problem parsing this message: \n" + m + "\n\n" +e);

    }

  } 
  else {

    println("History message - ignored");

  }

}

String parseSingleElement(String m, String t){
  int start = m.indexOf("<"+t+">") + t.length()+2;
  int end = m.indexOf("</"+t+">");
  return( m.substring(start, end));
}

String parseDoubleElement(String m, String e, String w){
  int start = m.indexOf("<"+e+">") + e.length()+2;
  int end = m.indexOf("</"+e+">");
  String t = m.substring(start, end);
  start = t.indexOf("<"+w+">") + w.length()+2;
  end = t.indexOf("</"+w+">");
  return( t.substring(start, end));
}

void pachube(){
  if (foundCC){


    for (int i = 0; i < numberOfClamps; i++){
      dOut.update(i+1, watts[i]); 
      output.println(watts[i]+"\t"+hour()+"\t"+minute()+"\t"+second());
    } 

    int response = dOut.updatePachube(); 
    if (response == 200){
      println("Pachube updated!");   
      debugMessage += "\n** updated Pachube **";
    } 
    else {



      debugMessage = "Problem updating Pachube\n";

      if (response == 404) debugMessage += "\nFeed does not exist";
      if (response == 401) debugMessage += "\nYou don't own that feed";
      if (response == 503) debugMessage += "\nPachube server error";

    }
  }
  else 
  {
    debugMessage = "No CurrentCost found\n** no Pachube update **";
  }
}

void loadPreferences(){

  try{
    String lines[] = loadStrings(loadPath);

    if (lines.length >= 4){
      serialDevice = int(lines[0]);
      numberOfClamps = constrain(int(lines[1]),1,9);
      pachubeURL = lines[2];
      pachubeAPI = lines[3];
      println(serialDevice);
      println(numberOfClamps);
      println(pachubeURL);
      println(pachubeAPI);

    } 
    else {
      savePrefs("0","1","http://","API_KEY");
      exit();   
    }

    setupGUI();

    historicValues = new int[numberOfClamps][historySize];

    for (int i = 0; i < numberOfClamps; i++){
      for (int j = 0; j< historySize; j++){
        historicValues[i][j] = 0;
      }   

    }

  }

  catch (Exception e){
    savePrefs("0","1","http://","API_KEY");
    fill(0);
    textFont(font, 18);
    text("Created new preferences\nfile... \nPlease restart app", 30, 30);
    exit();
  }
}

void savePrefs(String a, String b, String c, String d){

  try {
    String[] newSave;
    newSave = new String[4];
    newSave[0] = a;
    newSave[1] = b;
    newSave[2] = c;
    newSave[3] = d;
    saveStrings(loadPath, newSave);

    serialDevice = int(a);
    numberOfClamps = constrain(int(b),1,9);
    pachubeURL = c;
    pachubeAPI = d;
    println(serialDevice);
    println(numberOfClamps);
    println(pachubeURL);
    println(pachubeAPI);
    setupSerial(serial_speed[this_serial_speed]);
    setupPachube();
    historicValues = new int[numberOfClamps][historySize];

    for (int i = 0; i < numberOfClamps; i++){
      for (int j = 0; j< historySize; j++){
        historicValues[i][j] = 0;
      }   

    }

    println("Saved preferences");

  }
  catch (Exception e){
    println("There was a problem saving preferences: " + e);   
  }
}

void setupPachube(){
  dOut = new DataOut(this, pachubeURL, pachubeAPI);
  lastUpdate = millis();

}

void setupDatastreams(){

  if (unit == "C"){
    dOut.addData(0,"temperature, degrees, celsius");
    dOut.setUnits(0, "Celsius","C","basicSI");
  } 
  else if (unit == "F"){
    dOut.addData(0,"temperature, degrees, fahrenheit");
    dOut.setUnits(0, "Fahrenheit","F","conversionBasedUnits");
  }

  for (int i = 0; i < numberOfClamps; i++){
    watts[i] = 0;   
    dOut.addData(i+1,"watts, electricity, power");
    dOut.setUnits(i+1, "Watts","W","derivedSI");
  }

  datastreamsSet = true;

}

void keyPressed(){
  if (key==ESC){
    output.flush();
    output.close();
    exit();
  }
}
    
    
    
void drawPachube(){
  //                                                                                                                                   
//  image(pachube, 78, 265);
  fill(150,150,150);
  textFont(font, 14);
  text("www.pachube.com", 58, 310);
}

void drawGraph(){

  fill(255,255,255);
  stroke(0);
  strokeWeight(1);

  rect(20,175,210,65);

  stroke(230,230,230);

  for (int i = 1; i < 21; i++){        
    line(20 + i*10, 239, 20 + i* 10, 176);
  }

  color from = color(255, 0, 255);
  color to = color(0, 255,255 );

  int[] maxWatts;
  maxWatts = new int[numberOfClamps];

  for (int i = 0; i < numberOfClamps; i++){        
    maxWatts[i] = max(historicValues[i]);
  }

  int maxAllWatts = max(maxWatts);

  for (int i = 0; i < numberOfClamps; i++){      

    color graphLine = lerpColor(from, to, (float)i/(float)numberOfClamps);  
    stroke(graphLine);

    for (int j = 2; j < historySize; j++){
      float graphHeight1=63.0*(float)historicValues[i][j-1]/(float)maxAllWatts;
      float graphHeight2=63.0*(float)historicValues[i][j]/(float)maxAllWatts;
      line((float)19+j, height-231-graphHeight1, (float)20+j, height-231-graphHeight2);
    }

  }

  stroke(0);

}


void setupSerial(int serial_speed){
  try {
    String portName = Serial.list()[serialDevice];
    myPort = new Serial(this, portName, serial_speed);
    println("Set up serial port with speed: " + serial_speed);
    debugMessage = "CurrentCost\n\nNo info received yet\nDevice selected: \n"+Serial.list()[serialDevice]+"\n\nClamps: "+numberOfClamps;
    println(debugMessage);

  } 
  catch (Exception e){

    println("There was a problem setting up serial communication: " + e);

  }
  lastMessage = millis();
  buffer = "";
}



















