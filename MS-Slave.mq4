//+------------------------------------------------------------------+
//|                                                     MS-Slave.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 0.9 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

#define VERSION     "0.9"

//--- input parameters
extern bool CSV = true;
extern double LotFaktor = 1;
extern int MagicNumber = 11041963;

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
int anzahlMasterOrders = -1;
double MasterOrders[100][4];

int anzahlCurrentOrders;
double CurrentOrders[100][4];

string MasterOrderFile;
string MasterHandShakeFile;

string SlaveOrderFile;
string SlaveHandShakeFile;

string RunMode = " Slave: ";

int Flag;
int digits;

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
  SlaveOrderFile      = MasterOrderFile     + "." + AccountNumber();
  SlaveHandShakeFile  = MasterHandShakeFile + "." + AccountNumber();
 
  if (CSV) {
    Flag = FILE_CSV;
    MasterOrderFile   = MasterOrderFile + ".csv";
    SlaveOrderFile    = SlaveOrderFile  + ".csv";
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
  bool rc = true; 

  if (!rc || checkHandShake()) {
    anzahlMasterOrders = readOrders();
    anzahlCurrentOrders = getOrders();

    if (CurrentMasterOrdersDifferent()) {
      if (executeMasterOrders()) {
        if (DebugLevel > 1) Print(Symbol(), RunMode, "Abgleich erfolgreich");
        rc = writeHandShake(SlaveHandShakeFile);
        anzahlCurrentOrders = getOrders();
        rc = rc && writeOrders(SlaveOrderFile);
        if (rc) anzahlMasterOrders = copyCurrent2Master();
      } else {
        if (DebugLevel > 1) Print(Symbol(), RunMode, "Abgleich nicht erfolgreich.");
      }
    } else {
      rc = true;
    }
  }
//----
  return(0);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Überprüft, ob das Masterhandshakefile existiert, das             |
//| Slavehandshakefile aber nicht                                    |
//+------------------------------------------------------------------+ 
bool checkHandShake() {

  bool rc = false;
  int FH = FileOpen(SlaveHandShakeFile, FILE_BIN|FILE_READ);
  if (FH > 0) {
    FileClose(FH);
    if (DebugLevel > 3) Print (Symbol(), RunMode, "Slave-Change-Datei vorhanden -> Master-Change-Datei bereits ausgewertet");
  } else {
    FH = FileOpen(MasterHandShakeFile, FILE_BIN|FILE_READ);
    if (FH > 0) {
      FileClose(FH);
      // anzahlMasterOrders initialisieren
      rc = true;
      if (DebugLevel > 1) Print (Symbol(), RunMode, "Array MasterOrders aus Datei lesen");
    } else {
      if (DebugLevel > 3) Print (Symbol(), RunMode, "Keine Master-Change-Datei vorhanden");
    }
  }

  return (rc);
}


//+------------------------------------------------------------------+
//| Liest die Orders aus dem OrderFile                               |
//+------------------------------------------------------------------+ 
int readOrders() {

  int FH, i;

  int cnt = -1;
  ArrayInitialize(MasterOrders, 0);
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: Versuche MasterOrders aus Datei ", MasterOrderFile, " zu lesen (", Flag, ")");
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
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==false || 
        OrderSymbol()!= Symbol() || 
        OrderMagicNumber()!= MagicNumber || 
        (OrderType()!=OP_BUY && OrderType()!=OP_SELL))
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
  
  // Falls die Anzahl unterschiedlich ist, wird in jedem Fall die Orderdatei neu erstellt
  bool rebuild = anzahlCurrentOrders < anzahlMasterOrders;

  if (DebugLevel > 2) Print (Symbol(), RunMode, "Vergleiche Arrays: ");
  
  int i = 0;
  while (!rebuild && i<anzahlCurrentOrders){
    rebuild = MathRound(LotFaktor*100*MasterOrders[i][0])/100 != CurrentOrders[i][0] ||
              MasterOrders[i][1] != CurrentOrders[i][1] ||
              MasterOrders[i][2] != CurrentOrders[i][2];
    if (DebugLevel > 3) Print (Symbol(), RunMode, "MasterOrders:CurrentOrders[", i, "]:", MathRound(LotFaktor*100*MasterOrders[i][0])/100, ":", CurrentOrders[i][0], "|", MasterOrders[i][1], ":", CurrentOrders[i][1], "|", MasterOrders[i][2], ":", CurrentOrders[i][2], "|", MasterOrders[i][3], ":", CurrentOrders[i][3]);
    i++;
  }
  if (DebugLevel > 1) {
    if (rebuild) {
      Print (Symbol(), RunMode, "Unterschied bei MasterOrders(", anzahlMasterOrders, "):CurrentOrders(", anzahlCurrentOrders, ") Pos ", i, ":", MathRound(LotFaktor*100*MathAbs(MasterOrders[i][0]))/100, ":", CurrentOrders[i][0], "|", MasterOrders[i][1], ":", CurrentOrders[i][1], "|", MasterOrders[i][2], ":", CurrentOrders[i][2], "|", MasterOrders[i][3], ":", CurrentOrders[i][3]);
      Print (Symbol(), RunMode, "Vergleiche Arrays Ergebnis: Rebuild: ", rebuild);
    }
  }
  
  return(rebuild);
}


//+------------------------------------------------------------------+
//| Masterorders auf Slave ausführen                                 |
//+------------------------------------------------------------------+ 
bool executeMasterOrders() {

  bool rc = true;
  int ticket = -1;
  int mode;
  double price;
      
  for (int i=0; i<anzahlMasterOrders; i++) {
    // Falls eine Ticketnummer existiert, existiert bereits eine Order und diese wird modifiziert,
    // ansonsten wird die Order neu angelegt
    if (CurrentOrders[i][3] != 0) {
      ticket = MathFloor(CurrentOrders[i][3]);
      if (MasterOrders[i][2] != CurrentOrders[i][3] || MasterOrders[i][2] != CurrentOrders[i][3]) {
        if (DebugLevel > 0) Print(Symbol(), RunMode, "OrderModify(", ticket, ", 0, ", NormalizeDouble(MasterOrders[i][2], Digits), ", ", NormalizeDouble(MasterOrders[i][1], Digits), ", 0, CLR_NONE)");
        rc = rc && OrderModify(ticket, 0, NormalizeDouble(MasterOrders[i][2], Digits), NormalizeDouble(MasterOrders[i][1], Digits), 0, CLR_NONE);
      }
    } else {
      if (MasterOrders[i][0] < 0) {
        mode = OP_SELL;
        price = NormalizeDouble(Bid, Digits);
      } else {
        mode = OP_BUY;
        price = NormalizeDouble(Ask, Digits);
      }
      
      int retry = 0;
      ticket = -1;
      while ((ticket == -1) && (retry < 10)) {
        RefreshRates();
        ticket = OrderSend(Symbol(), mode, MathRound(LotFaktor*100*MathAbs(MasterOrders[i][0]))/100, price, 3, 0, 0, "MS-" + Symbol() + "-" + i, MagicNumber, 0, CLR_NONE);
        if (ticket > 0) {
          rc = rc && OrderModify(ticket, 0, NormalizeDouble(MasterOrders[i][2], Digits), NormalizeDouble(MasterOrders[i][1], Digits), 0, CLR_NONE);
          if (DebugLevel > 0) Print(Symbol(), RunMode, "OrderSend(", Symbol(), ", ", mode, ", ", MathRound(LotFaktor*100*MathAbs(MasterOrders[i][0]))/100, ", ", price, ", 3,", MasterOrders[i][2], ", ", MasterOrders[i][1], ", Slave, ", MagicNumber, ", 0, CLR_NONE) TP/SL set: ", rc);
        }
        retry++;
      }
      if (ticket < 0) {
        if (DebugLevel > 0) Print(Symbol(), RunMode, "OrderSend(", Symbol(), ", ", mode, ", ", MathRound(LotFaktor*100*MathAbs(MasterOrders[i][0]))/100, ", ", price, ", 3,", MasterOrders[i][2], ", ", MasterOrders[i][1], ", Slave, ", MagicNumber, ", 0, CLR_NONE) failed with error #",GetLastError());
        rc = false;
      }
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
//| schreibt das HandShakeFile                                       |
//+------------------------------------------------------------------+ 
bool writeHandShake(string File) {

  int FH;
  bool rc = true; 

  if (DebugLevel > 1) Print(Symbol(), RunMode, "Anlegen des Handshakefile");
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
      if (MasterOrders[i][0] > 0) {
        SELLBUY = "Sell";
      } else {
        SELLBUY = "Buy";
      }
      if (diff) Print (Symbol(), RunMode, "Order[", i, ",", MasterOrders[i][3], "]: Symbol: ", Symbol(), ", Lots: ", SELLBUY, " ", MathAbs(MasterOrders[i][0]), "(", MasterOrders[i][0], "), TP: ", MasterOrders[i][1], ", SL: ", MasterOrders[i][2]);
    }
  }
  
  return(anzahlCurrentOrders);
}