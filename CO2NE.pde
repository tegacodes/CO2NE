static public class FPS {
  static private int frames = 0;
  static private long startTime = 0;
  static private int fps = 0;
  static private PApplet p;
  static FPS instance;
  public static void register(PApplet p){    
    instance = new FPS();
    FPS.p = p;
    p.registerPost(instance);
  }

  public static void frame() {
    if (startTime==0)
      startTime = p.millis();
    frames++;
    long t = p.millis() - startTime;
    if (t>1000) {
      fps = (int)(1000*frames/t);
      startTime += t;
      frames = 0;
    }
  }

  static public int frameRate(){
    return fps;
  }
  public void post(){
    FPS.frame();
  }  
}

//---------------------------------

import eeml.*; //library for connections to pachube
DataIn dIn;

float px, py, px2, py2;
float angle, angle2;
float r,r1 ;
float frequency = 0.00333; //(for an hour these need to be 0.003333
float frequency2 = 0.1998; // for minute this needs to be 0.1998
float x, x2;
float myVariable, myVariable1, temperature;
int s;
int h;
int m;

//INSTALLATION VARIABLES
float coneHeight=2.86;//m
float pressure = 100000; //hPa
float emissionC = 0.89; // emissions constant - scope 2 for NSW, for different cones refer to different values in 
float gasC = 8.314472;
float pixelC=444.44;




void setup()
{
  background(0);
  size( 1280, 800 );	
  // fill(255);
  stroke(255);
  strokeWeight(1);
  frameRate(30);

//Enter pachube feed here 
  dIn = new DataIn(this,"URL of PACHUBE FEED HERE", "PACHUBE KEY HERE", 10000);
  FPS.register(this);
  myVariable=myVariable1;
  r=r1;
  h = hour()%12;
  m = minute();
  s = second();
  angle = -90+6*m;// starts hand off in the right place
} 

void draw()
{
frame.setLocation(0,0);
//GRADUAL CHANGE IN LINE
if (r==0){
    r=0.1; 
    r=r1;
  }else{ 
if(r1>r){
    r++;
    }
    if(r1<r){
      r--;
    }
 //draw ellipses that make up cone
    px = width/2 +cos(radians(angle))*(r);
    py = height/2 + sin(radians(angle))*(r);
    ellipseMode(CENTER);
    fill(255);
    ellipse(px,py,1,1);
    noStroke();
    angle += frequency;
    x+=1;
 //make old ellipses fade out after the hour   
 if (angle>270) {
      noStroke();
      fill(0,0,0,160); //fills screen with semitransparent rectangle
      rect(0,0,width,height);
          angle=-90;
 }
    //  println(myVariable1);
    //  println("frames per second: " + FPS.frameRate());
  }
  println(angle);
}

void onReceiveEEML(DataIn d){ 
  myVariable1 = d.getValue(1)/1000; // get the value of the stream 1
  temperature= d.getValue(0)+273; //temperature data for gas volume equation
  r1 = pixelC*sqrt((3*myVariable1*20.2227*gasC*temperature)/(pressure*coneHeight*PI)); //radius calculation
}

//removes header etc for for projector display 
public void init() {
  frame.removeNotify();
  frame.setUndecorated(true);
  frame.addNotify();
  // call PApplet.init() to take care of business
  super.init();  
}



