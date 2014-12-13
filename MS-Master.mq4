//+------------------------------------------------------------------+
//|                                                    MS-Master.mq4 |
//|                                                      Peter Kempf |
//|                                                     Version 0.92 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

#define VERSION     "0.9"

#define WARTEZEIT   300

//--- input parameters
extern bool CSV = true;

extern int DebugLevel = 1;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderänderungen werden protokolliert
// Level 2: Alle Änderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

// Imports
#import "kernel32.dll"
int  FindFirstFileA(string path, int& answer[]);
bool FindNextFileA(int handle, int& answer[]);
bool FindClose(int handle);
#import

// Global variables
int MagicNumber = 11041963;

int anzahlMasterOrders = -1;
double MasterOrders[100][4];

int anzahlCurrentOrders;
double CurrentOrders[100][4];

string MasterOrderFile;
string MasterHandShakeFile;

string RunMode = " Master: ";

int Flag;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
//----
  Print ("Version: ", VERSION);

  anzahlMasterOrders = -1;
  
  Flag = FILE_BIN;
  MasterOrderFile     = Symbol() + ".trades";
  MasterHandShakeFile = Symbol() + ".change";
 
  if (CSV) {
    Flag = FILE_CSV;
    MasterOrderFile   = MasterOrderFile + ".csv";
  }
  
//----
  return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
//----
   
//----
  return(0);
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
//----
  bool rc; 

  if (anzahlMasterOrders < 0) anzahlMasterOrders = readOrders();

  if (CurrentMasterOrdersDifferent()) {
    rc = writeOrders(MasterOrderFile);
    rc = rc && deleteHandShake(MasterHandShakeFile + ".*");
    rc = rc && writeHandShake(MasterHandShakeFile);
    if (rc) anzahlMasterOrders = copyCurrent2Master();
  }
//----
  return(0);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Liest die Orders aus dem OrderFile                               |
//+------------------------------------------------------------------+ 
int readOrders() {

  int FH, i;

  int cnt = -1;
  ArrayInitialize(MasterOrders, 0);
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: Versuche MasterOrders aus Datei zu lesen");
  FH = FileOpen(MasterOrderFile, Flag|FILE_READ);
  if (FH > 0){
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: Dateihandle erfolgreich angelegt");
    if (FileSize(FH) > 0) {
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: ", MasterOrderFile, " vorhanden. Filesize ",FileSize(FH));
      if (CSV) {
        double wert = FileReadNumber(FH);
        while (!FileIsEnding(FH) && wert != 0) {
          cnt++;
          MasterOrders[cnt][0] = wert;
          if (DebugLevel > 3) Print (Symbol(), RunMode, "Wert [", cnt, "][0] gelesen: ", MasterOrders[cnt][0]);
          i = 1;
          while (!FileIsLineEnding(FH)) {
            MasterOrders[cnt][i] = FileReadNumber(FH);
            if (DebugLevel > 3) Print (Symbol(), RunMode, "Wert [", cnt, "][", i,"] gelesen: ", MasterOrders[cnt][i]);
            i++;
          }
          wert = FileReadNumber(FH);
        }
        cnt++;
      } else {
        FileReadArray(FH, MasterOrders, 0, 400);
        cnt = 0;
        while (MasterOrders[cnt][0] != 0 && cnt < 100) cnt++;
      }
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Array MasterOrders Datei lesen: ", cnt, " Elemente eingelesen");
      if (DebugLevel > 3) for (i=0; i<cnt; i++) Print (Symbol(), RunMode, "MasterOrders[", i, "]:", MasterOrders[i][0], ":", MasterOrders[i][1], ":", MasterOrders[i][2], ":", MasterOrders[i][3]);
    } else {
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Array MasterOrders Datei lesen: ", MasterOrderFile, " ist leer");
    } 
    FileClose(FH);
  } else {
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Array MasterOrders Datei lesen: ", MasterOrderFile, " ist nicht vorhanden");
  }
  
  return(cnt);
}


//+------------------------------------------------------------------+
//| ermittelt die aktiven Orders                                     |
//+------------------------------------------------------------------+ 
int getOrders() {

  int i, j, k;
  double Lots;

  int cnt = 0;
  int totalOrders = OrdersTotal();
  ArrayInitialize(CurrentOrders, 0);

  if (DebugLevel > 2) Print (Symbol(), RunMode, "Orderbuch auslesen (Total alle Symbole: ", totalOrders, ")");
  for(i=0; i<totalOrders; i++) {
    // Nur das aktuelle Symbol wird ausgewertet und nur aktive SELL- oder BUY-Positionen
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==false || OrderSymbol()!=Symbol() || (OrderType()!=OP_BUY && OrderType()!=OP_SELL))
      continue;
    // SELL Orders werden mit negativer Lotanzahl dargestellt
    Lots = OrderLots();
    // Das Array wird nach Lotanzahl aufsteigend sortiert 
    j = 0;
    while (j<cnt && Lots>=CurrentOrders[j][0]) j++;
    for (k=cnt; k>j; k--) { 
      CurrentOrders[k][0] = CurrentOrders[k-1][0];
      CurrentOrders[k][1] = CurrentOrders[k-1][1];
      CurrentOrders[k][2] = CurrentOrders[k-1][2];
      CurrentOrders[k][3] = CurrentOrders[k-1][3];
    }
    if (OrderType()==OP_SELL) Lots = -Lots;
    CurrentOrders[j][0] = Lots; 
    CurrentOrders[j][1] = OrderTakeProfit(); 
    CurrentOrders[j][2] = OrderStopLoss(); 
    CurrentOrders[j][3] = OrderTicket(); 
    cnt++;
  }
  if (DebugLevel > 2) Print (Symbol(), RunMode, "Orderbuch auslesen Anzahl: ", cnt);
  if (DebugLevel > 3) for (i=0; i<cnt; i++) Print (Symbol(), RunMode, "CurrentOrder[", i, "]:", CurrentOrders[i][0], ":", CurrentOrders[i][1], ":", CurrentOrders[i][2], ":", CurrentOrders[i][3]);
  
  return(cnt);
}


//+------------------------------------------------------------------+
//| Vergleich der aktiven Orders mit den gespeicherten Orders        |
//+------------------------------------------------------------------+ 
bool CurrentMasterOrdersDifferent() {
  
  int maxWait = 0;
  bool rc = false;

  if (DebugLevel > 2) Print (Symbol(), RunMode, "Vergleiche Arrays: ");
  
  anzahlCurrentOrders = getOrders();
  
  int lastanzahlCurrentOrders = anzahlCurrentOrders;
  if (anzahlCurrentOrders < anzahlMasterOrders) {
    // Falls eine Order geschlossen wurde, warten wird ab, bis
    // das System damit durch ist
    if (DebugLevel > 0) Print (Symbol(), RunMode, "Aktuelle Orders geringer als MasterOrders: ", anzahlCurrentOrders, "<", anzahlMasterOrders);
    while (anzahlCurrentOrders != 0 && maxWait < WARTEZEIT) {
      Sleep(1000);
      maxWait++;
      lastanzahlCurrentOrders = anzahlCurrentOrders;
      anzahlCurrentOrders = getOrders();
      if (DebugLevel > 0 && maxWait < 20) Print (Symbol(), RunMode, "MasterOrders: ", anzahlMasterOrders, " Letzte CurrentOrders: ", lastanzahlCurrentOrders, " CurrentOrders: ", anzahlCurrentOrders);
    }
    if (DebugLevel > 0) Print (Symbol(), RunMode, "Wartezeit: ", maxWait, " Aktuelle Orders: ",  anzahlCurrentOrders, " Masterorders: ", anzahlMasterOrders);
  }

  rc = anzahlCurrentOrders != anzahlMasterOrders;

  int i = 0;
  while (!rc && i<anzahlCurrentOrders){
    rc = MasterOrders[i][0] != CurrentOrders[i][0] ||
         MasterOrders[i][1] != CurrentOrders[i][1] ||
         MasterOrders[i][2] != CurrentOrders[i][2];
    if (DebugLevel > 3) Print (Symbol(), RunMode, "MasterOrders:CurrentOrders[", i, "]:", MasterOrders[i][0], ":", CurrentOrders[i][0], "|", MasterOrders[i][1], ":", CurrentOrders[i][1], "|", MasterOrders[i][2], ":", CurrentOrders[i][2], "|", MasterOrders[i][3], ":", CurrentOrders[i][3]);
    i++;
  }
  if (DebugLevel > 1) {
    if (rc) {
      Print (Symbol(), RunMode, "Unterschied bei MasterOrders(", anzahlMasterOrders, "):CurrentOrders(", anzahlCurrentOrders, ") Pos ", i, ":", MasterOrders[i][0], ":", CurrentOrders[i][0], "|", MasterOrders[i][1], ":", CurrentOrders[i][1], "|", MasterOrders[i][2], ":", CurrentOrders[i][2], "|", MasterOrders[i][3], ":", CurrentOrders[i][3]);
      Print (Symbol(), RunMode, "Vergleiche Arrays Ergebnis: Rebuild: ", rc);
    }
  }
  
  return(rc);
}


//+------------------------------------------------------------------+
//| schreibt die Orders in das OrderFile                             |
//+------------------------------------------------------------------+ 
bool writeOrders(string File) {

  int FH;
  bool rc = true; 
  
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Schreibe CurrentOrders Arrays");
  FH = FileOpen(File, Flag|FILE_WRITE);
  if (FH < 0) {
    if (GetLastError()==4103) Alert(Symbol(), RunMode, "No file named ", MasterOrderFile);
    else Alert(Symbol(), RunMode, "Error while opening file ", MasterOrderFile, " ", GetLastError());
    rc = false;
  }

  if (CSV) {
    for (int i=0; i<anzahlCurrentOrders; i++) {
      if (FileWrite(FH, CurrentOrders[i][0], CurrentOrders[i][1], CurrentOrders[i][2], CurrentOrders[i][3]) < 0) {
        Alert(Symbol(), RunMode, "Error writing to the file ", MasterOrderFile, " ", GetLastError());
        rc = false;
      }
    }  
  } else {
    if (FileWriteArray(FH, CurrentOrders, 0, 4*anzahlCurrentOrders) < 0) {
      Alert(Symbol(), RunMode, "Error writing to the file ", MasterOrderFile, " ", GetLastError());
      rc = false;
    }   
  }
  FileClose(FH);
  
  return(rc);
}


//+------------------------------------------------------------------+
//| Löscht alle existierenden Slavehandshakefiles                    |
//+------------------------------------------------------------------+ 
bool deleteHandShake(string file) {

  int LP[82];
  string FileName;

  if (DebugLevel > 1) Print (Symbol(), RunMode, "Lösche alle Slavehandshakefiles");
  
  int FH = FindFirstFileA(TerminalPath() + "\experts\files\\" + file, LP);
  
  if (FH > 0) {
    FileName = bufferToString(LP);
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Lösche ", FileName);
    FileDelete(FileName);
    ArrayInitialize(LP,0);
    while (FindNextFileA(FH,LP)) {
      FileName = bufferToString(LP);
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Lösche ", FileName);
      FileDelete(FileName);
      ArrayInitialize(LP,0);
    }
 
    FindClose(FH);
  } else {
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Error: ", GetLastError());
  }
    
  return(true);
}


//+------------------------------------------------------------------+
//| schreibt das HandShakeFile                                       |
//+------------------------------------------------------------------+ 
bool writeHandShake(string File) {

  int FH;
  bool rc = true; 

  if (DebugLevel > 1) Print(Symbol(), RunMode, "Anlegen des Masterhandshakefile");
  FH = FileOpen(File, FILE_BIN|FILE_WRITE);
  if (FH < 0) {
    if (GetLastError()==4103) Alert(Symbol(), RunMode, "No file named ", MasterHandShakeFile);
    else Alert(Symbol(), RunMode, "Error while opening file ", MasterHandShakeFile, " ", GetLastError());
    rc = false;
  } else {
    if (FileWrite(FH, anzahlCurrentOrders) < 0) {
      Alert(Symbol(), RunMode, "Error writing to the file ", MasterHandShakeFile, " ", GetLastError());
      rc = false;
    }
    FileClose(FH);
  }
  return(rc);
}
 
 
//+------------------------------------------------------------------+
//| Kopiert die aktuellen Orders nach Masterorders                   |
//+------------------------------------------------------------------+ 
int copyCurrent2Master() {

  bool diff;

  ArrayInitialize(MasterOrders, 0);
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Uebernehme aktuelle Orders nach Master Orders");
  for (int i=0; i<anzahlCurrentOrders; i++) {
    diff = false;
    for (int j=0; j<4; j++) {
      if (MasterOrders[i][j] != CurrentOrders[i][j]) {
        diff = true;
        MasterOrders[i][j] = CurrentOrders[i][j];
      }
    }
    if (DebugLevel > 0) {
      string SELLBUY;
      if (MasterOrders[i][0] < 0) {
        SELLBUY = "Sell";
      } else {
        SELLBUY = "Buy";
      }
      if (diff) Print (Symbol(), RunMode, "Order[", i, ",", MasterOrders[i][3], "]: Symbol: ", Symbol(), ", Lots: ", SELLBUY, " ", MathAbs(MasterOrders[i][0]), "(", MasterOrders[i][0], "), TP: ", MasterOrders[i][1], ", SL: ", MasterOrders[i][2]);
    }
  }
  
  return(anzahlCurrentOrders);
}


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Konvertiert einen Filebufferinhalt in einen Textstring           |
//+------------------------------------------------------------------+ 
string bufferToString(int buffer[]) {

  string text="";
   
  for (int i=11; i<76; i++) {
    int curr = buffer[i];
    text = text + CharToStr(curr & 0x000000FF)
                + CharToStr(curr >> 8 & 0x000000FF)
                + CharToStr(curr >> 16 & 0x000000FF)
                + CharToStr(curr >> 24 & 0x000000FF);
  }
  return(text);
}  

