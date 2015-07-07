//--------------------------------------------------------------------
// MasterSlave.mq4
// Sammelt vom Master Orders und setzt sie auf den Slaves um
//--------------------------------------------------------------------

// Konstanten
 
// Imports
#import "kernel32.dll"
int  FindFirstFileA(string path, int& answer[]);
bool FindNextFileA(int handle, int& answer[]);
bool FindClose(int handle);
#import

// External variables
extern int MagicNumber = 11041963;
extern bool Master = true;
extern bool CSV = true;
extern double LotFaktor = 1;

extern int DebugLevel = 4;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderänderungen werden protokolliert
// Level 2: Alle Änderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

// Global variables
int anzahlMasterOrders = -1;
double MasterOrders[100][4];

int anzahlCurrentOrders;
double CurrentOrders[100][4];

string MasterOrderFile;
string MasterHandShakeFile;

string SlaveOrderFile;
string SlaveHandShakeFile;

bool Slave = true;
string RunMode = " Slave: ";

int Flag;

// int TickCount = 0;

//--------------------------------------------------------------------
int init() {
  anzahlMasterOrders = -1;
  
  if (Master) {
    Slave = false;
    LotFaktor = 1;
    RunMode = " Master: ";
  }
  
  Flag = FILE_BIN;
  MasterOrderFile     = Symbol();
  MasterHandShakeFile = Symbol() + ".change";
  SlaveOrderFile      = MasterOrderFile     + "." + AccountNumber();
  SlaveHandShakeFile  = MasterHandShakeFile + "." + AccountNumber();
 
  if (CSV) {
    Flag = FILE_CSV;
    MasterOrderFile   = MasterOrderFile + ".csv";
    SlaveOrderFile    = SlaveOrderFile  + ".csv";
  }
  
  return(0);
}   
   
//--------------------------------------------------------------------
int start() {

  bool rc; 
//  int pos;
//  int totalOrders;
//  double Lots;

//   TickCount++;
  
//  if (Master) {
//    // Master: Löschen des Handshakefiles wenn es älter als zwei Ticks
//    // ist
//    FH = FileOpen(MasterHandShakeFile, FILE_BIN|FILE_READ);
//    if (FH>0) {
//      FileClose(FH);
//      if (DebugLevel > 1) Print (Symbol(), " Master: Master-Change-Datei vorhanden");
//      if (TickCount > 2) {
//        FileDelete(MasterHandShakeFile);
//        if (DebugLevel > 1) Print (Symbol(), " Master: Master-Change-Datei gelöscht");
//      }
//    }
//  } else {

  /*------------------------------------------------------------------
     Slave:
     Falls die Masterhandshakedatei existiert und die Slavehandshake-
     datei nicht existiert, wird die AnzahlMasterOrders zurückgesetzt 
     und dadurch ein Einlesen der MasterOrderdatei erzwungen.
     Master:
     AnzahlMasterOrders wird via init() auf -1 gesetzt und dadurch 
     einmalig ein Einlesen der MasterOrderDatei veranlaßt. Ein wieder-
     holtes Einlesen ist nicht nötig, da ab der Initialisierung die 
     Daten im Speicher gehalten werden. Beim Auftreten neuer  Orders 
     wird der Speicher und die Datei aktualisiert.
  */
  anzahlMasterOrders = checkHandShake();
  
  /*------------------------------------------------------------------
     Falls der Array MasterOrders nicht belegt ist (Master), oder die
     Handshakedateien erneuert wurden (Slave) wird getestet, ob die 
     Orderdatei <SYMBOL> existiert und ggf. in den Array MasterOrders 
     einlesen.
     Einlesen der Orderdatei:
     Aufbau einer Zeile der Liste / eines Elements des Arrays:
       * Lotzahl (Negativ bei SELL, positiv bei BUY)
       * TakeProfit
       * StopLoss
       * Auftragsnummer
  */
  if (anzahlMasterOrders < 0) anzahlMasterOrders = readOrders();
  
  /*------------------------------------------------------------------
     Abfrage aller aktiven Orders eines Symbols; Ablage im Array 
     CurrentOrders sortiert in Richtung aufsteigender Lotzahl
       * Lotzahl (Negativ bei SELL, positiv bei BUY)
       * TakeProfit
       * StopLoss
       * Auftragsnummer
  */
  anzahlCurrentOrders = getOrders();
    
  /*------------------------------------------------------------------
     Vergleich der eingelesenen Datei mit den ermittelten Werten
     unter Berücksichtigung des Lotfaktors (Slave)
     Verglichen wird:
       * Lotzahl (Negativ bei SELL, positiv bei BUY)
       * TakeProfit
       * StoppLoss
     - keine Unterschiede -> ENDE
     - Unterschiede
       Master:
         - die gesamte Orderdatei <Symbol> wird neu erzeugt
         - es wird eine Handshakedatei <SYMBOL>.change angelegt
         - ENDE
       Slave:
         - Order vorhanden -> Es wird ein OrderModify() abgesetzt
         - Order nicht vorhanden -> Es wird ein OrderSend() abgesetzt
         - Die MasterHandShakeDatei <SYMBOL>.change wird auf die
           SlaveHandShakeDatei <SYMBOL>.change.<Accountnummer> kopiert
  */
  if (CurrentMasterOrdersDifferent()) {
    // Verarbeiten der CurrentOrders
    if (Master) {
      // Schreiben des Masterorderfiles
      rc = writeOrders(MasterOrderFile);

      // Löschen aller Handshakefiles
      rc = rc && deleteHandShake();
      
      // Schreiben des Masterhandshakefiles
      rc = rc && writeHandShake(MasterHandShakeFile);

      // Umkopieren der CurrentOrders nach MasterOrders
      if (rc) anzahlMasterOrders = copyCurrent2Master();
    } else {
      // Lesen und Ausführen der Masterorders
      if (executeMasterOrders()) {
        // Bei Erfolg Anlegen des Slaveorder- und handshakefiles
        if (DebugLevel > 1) Print(Symbol(), RunMode, "Abgleich erfolgreich");
          
        // Anlegen des Slaveorderfiles
        /*------------------------------------------------------------------
           Abfrage aller aktiven Orders eines Symbols; Ablage im Array 
           CurrentOrders sortiert in Richtung aufsteigender Lotzahl
             * Lotzahl (Negativ bei SELL, positiv bei BUY)
             * TakeProfit
             * StopLoss
             * Auftragsnummer
        */

        // Anzahl aktueller Orders neu ermitteln, da ggf. neue Orders dazu kamen
        anzahlCurrentOrders = getOrders();

        rc = writeOrders(SlaveOrderFile);

        rc = rc && writeHandShake(SlaveHandShakeFile);
 
      } else {
        if (DebugLevel > 1) Print(Symbol(), RunMode, "Abgleich nicht erfolgreich.");
      }
    }
  }
  return(0);
}
   
//--------------------------------------------------------------------
int deinit() {
  return(0);
}


//+------------------------------------------------------------------+
//| Überprüft, ob das Masterhandshakefile existiert, das             |
//| Slavehandshakefile aber nicht                                    |
//+------------------------------------------------------------------+ 
int checkHandShake() {

  int FH;

  if (Slave) {
    FH = FileOpen(SlaveHandShakeFile, FILE_BIN|FILE_READ);
    if (FH>0) {
      FileClose(FH);
      if (DebugLevel > 3) Print (Symbol(), RunMode, "Slave-Change-Datei vorhanden -> Master-Change-Datei bereits ausgewertet");
//      if (TickCount > 3) {
//        FileDelete(SlaveHandShakeFile);
//        if (DebugLevel > 1) Print (Symbol(), " Slave: Slave-Change-Datei gelöscht");
//      }
    } else {
      FH = FileOpen(MasterHandShakeFile, FILE_BIN|FILE_READ);
      if (FH>0) {
        FileClose(FH);
//        TickCount = 0;
        // anzahlMasterOrders initialisieren
        anzahlMasterOrders = -1;
        if (DebugLevel > 1) Print (Symbol(), RunMode, "Array MasterOrders aus Datei lesen");
      } else {
        if (DebugLevel > 3) Print (Symbol(), RunMode, "Keine Master-Change-Datei vorhanden");
      }
    }
  }

  return (anzahlMasterOrders);
}


//+------------------------------------------------------------------+
//| Liest die Orders aus dem OrderFile                               |
//+------------------------------------------------------------------+ 
int readOrders() {

  int FH, pos;

  int cnt = -1;
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: Versuche MasterOrders aus Datei zu lesen");
  FH = FileOpen(MasterOrderFile, Flag|FILE_READ);
  if (FH > 0){
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: Dateihandle erfolgreich angelegt");
    if (FileSize(FH) > 0) {
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Initialisierung Array MasterOrders: ", MasterOrderFile, " vorhanden. Filesize ",FileSize(FH));
      if (CSV) {
        double wert = FileReadNumber(FH);
        while (!FileIsEnding(FH) && wert > 0) {
          if (wert > 0) {
            cnt++;
            MasterOrders[cnt][0] = wert;
            if (DebugLevel > 3) Print (Symbol(), RunMode, "Wert [", cnt, "][0] gelesen: ", MasterOrders[cnt][0]);
            pos = 1;
            while (!FileIsLineEnding(FH)) {
              MasterOrders[cnt][pos] = FileReadNumber(FH);
              if (DebugLevel > 3) Print (Symbol(), RunMode, "Wert [", cnt, "][", pos,"] gelesen: ", MasterOrders[cnt][pos]);
              pos++;
            }
            wert = FileReadNumber(FH);
          }
        }
        cnt++;
      } else {
        FileReadArray(FH, MasterOrders, 0, 400);
        cnt = 0;
        while (MasterOrders[cnt][0] != 0 && cnt < 100) cnt++;
      }
      if (DebugLevel > 2) Print (Symbol(), RunMode, "Array MasterOrders Datei lesen: ", cnt, " Elemente eingelesen");
      for (pos=0; pos<cnt; pos++) {
        if (DebugLevel > 3) Print (Symbol(), RunMode, "MasterOrders[", pos, "]:", MasterOrders[pos][0], ":", MasterOrders[pos][1], ":", MasterOrders[pos][2], ":", MasterOrders[pos][3]);
      }
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
//| schreibt die Orders in das OrderFile                             |
//+------------------------------------------------------------------+ 
bool writeOrders(string File) {

  int FH;
  
  if (DebugLevel > 1) Print (Symbol(), RunMode, "Schreibe CurrentOrders Arrays");
  FH = FileOpen(File, Flag|FILE_WRITE);
  if (FH<0) {
    if (GetLastError()==4103)         // If the file does not exist,..
      Alert(Symbol(), RunMode, "No file named ", MasterOrderFile);
    else
      Alert(Symbol(), RunMode, "Error while opening file ", MasterOrderFile);
    return(false);
  }
      
  if (CSV) {
    for (int pos=0; pos<anzahlCurrentOrders; pos++) {
      if (FileWrite(FH, CurrentOrders[pos][0], CurrentOrders[pos][1], CurrentOrders[pos][2], CurrentOrders[pos][3]) < 0) {
        Alert(Symbol(), RunMode, "Error writing to the file",GetLastError());
        return(false);
      }
    }  
  } else {
    if (FileWriteArray(FH, CurrentOrders, 0, 4*anzahlCurrentOrders) < 0) {
      Alert(Symbol(), RunMode, "Error writing to the file", GetLastError());
      return(false);
    }   
  }
  FileClose(FH);
  
  return(true);
}


//+------------------------------------------------------------------+
//| Konvertiert einen Filebufferinhalt in einen Textstring           |
//+------------------------------------------------------------------+ 
string bufferToString(int buffer[]) {

  string text="";
   
//  int pos = 11;
  int pos = 10;
  for (int i=0; i<65; i++) {
    pos++;
    int curr = buffer[pos];
    text = text + CharToStr(curr & 0x000000FF)
                + CharToStr(curr >> 8 & 0x000000FF)
                + CharToStr(curr >> 16 & 0x000000FF)
                + CharToStr(curr >> 24 & 0x000000FF);
  }
  return (text);
}  


//+------------------------------------------------------------------+
//| Löscht alle existierenden Handshakefiles                         |
//+------------------------------------------------------------------+ 
bool deleteHandShake() {

  int LP[82];
  string FileName;

  if (DebugLevel > 1) Print (Symbol(), RunMode, "Lösche alle Handshakefiles und schreibe Masterhandshakefile");
  
  int handle = FindFirstFileA(TerminalPath() + "\experts\files\\" + MasterHandShakeFile + "*", LP);
  // Print("error = ", GetLastError());
  FileName = bufferToString(LP);
  if (DebugLevel > 2) Print (Symbol(), RunMode, "Lösche ", FileName);
  FileDelete(FileName);
  ArrayInitialize(LP,0);
  while (FindNextFileA(handle,LP)) {
    FileName = bufferToString(LP);
    if (DebugLevel > 2) Print (Symbol(), RunMode, "Lösche ", FileName);
    FileDelete(FileName);
    ArrayInitialize(LP,0);
  }
 
  if (handle>0) FindClose(handle);
   
  return(0);
}


//+------------------------------------------------------------------+
//| schreibt das HandShakeFile                                       |
//+------------------------------------------------------------------+ 
bool writeHandShake(string File) {

  int FH;

  if (DebugLevel > 1) Print(Symbol(), RunMode, "Anlegen des Handshakefile");
  FH = FileOpen(File, FILE_BIN|FILE_WRITE);
  if (FH>0) {
    if (FileWrite(FH, anzahlCurrentOrders) < 0) {
      Alert(Symbol(), RunMode, "Error writing to the file", GetLastError());
      return(false);
    }   
    FileClose(FH);
//    TickCount = 0;
  } else {
    if (FH<0) {
      if (GetLastError()==4103) Alert(Symbol(), RunMode, "No file named ", MasterHandShakeFile);
      else Alert(Symbol(), RunMode, "Error while opening file ", MasterHandShakeFile);
      return(false);
    }
  }  

  return(true);
}
 
 
//+------------------------------------------------------------------+
//| ermittelt die aktiven Orders                                     |
//+------------------------------------------------------------------+ 
int getOrders() {

  int pos, pos2, pos3, Lots;

  int cnt = 0;
  ArrayInitialize(CurrentOrders, 0);
  int totalOrders = OrdersTotal();
  if (DebugLevel > 2) Print (Symbol(), RunMode, "Orderbuch auslesen (Total alle Symbole: ", totalOrders, ")");
  for(pos=0; pos<totalOrders; pos++) {
    // Nur das aktuelle Symbol wird ausgewertet und nur aktive SELL- oder BUY-Positionen
    if (OrderSelect(pos, SELECT_BY_POS, MODE_TRADES)==false || OrderSymbol()!=Symbol() || (OrderType()!=OP_BUY && OrderType()!=OP_SELL))
      continue;
    // SELL Orders werden mit negativer Lotanzahl dargestellt
    Lots = OrderLots();
    if (OrderType()==OP_SELL) Lots = -Lots;
    // Das Array wird nach Lotanzahl aufsteigend sortiert 
    pos2 = 0;
    while (pos2<cnt && Lots>=CurrentOrders[pos2][0]) pos2++;
    for (pos3=cnt; pos3>pos2; pos3--) { 
      CurrentOrders[pos3][0] = CurrentOrders[pos3-1][0];
      CurrentOrders[pos3][1] = CurrentOrders[pos3-1][1];
      CurrentOrders[pos3][2] = CurrentOrders[pos3-1][2];
      CurrentOrders[pos3][3] = CurrentOrders[pos3-1][3];
    }
    CurrentOrders[pos2][0] = Lots; 
    CurrentOrders[pos2][1] = OrderTakeProfit(); 
    CurrentOrders[pos2][2] = OrderStopLoss(); 
    CurrentOrders[pos2][3] = OrderTicket(); 
    cnt++;
  }
  if (DebugLevel > 2) Print (Symbol(), RunMode, "Orderbuch auslesen Anzahl: ", cnt);
  for (pos=0; pos<cnt; pos++) {
    if (DebugLevel > 3) Print (Symbol(), RunMode, "CurrentOrder[", pos, "]:", CurrentOrders[pos][0], ":", CurrentOrders[pos][1], ":", CurrentOrders[pos][2], ":", CurrentOrders[pos][3]);
  }
  
  return(cnt);
}


//+------------------------------------------------------------------+
//| Vergleich der aktiven Orders mit den gespeicherten Orders        |
//+------------------------------------------------------------------+ 
bool CurrentMasterOrdersDifferent() {
  
  // Falls die Anzahl unterschiedlich ist, wird in jedem Fall die Orderdatei neu erstellt
  bool rebuild = anzahlCurrentOrders != anzahlMasterOrders;

  if (DebugLevel > 2) Print (Symbol(), RunMode, "Vergleiche Arrays: ");
  
  int pos = 0;
  while (!rebuild && pos<anzahlCurrentOrders){
    rebuild = MathRound(LotFaktor*100*MasterOrders[pos][0])/100 != CurrentOrders[pos][0] ||
              MasterOrders[pos][1] != CurrentOrders[pos][1] ||
              MasterOrders[pos][2] != CurrentOrders[pos][2];
    if (DebugLevel > 3) Print (Symbol(), RunMode, "MasterOrders:CurrentOrders[", pos, "]:", MathRound(LotFaktor*100*MasterOrders[pos][0])/100, ":", CurrentOrders[pos][0], "|", MasterOrders[pos][1], ":", CurrentOrders[pos][1], "|", MasterOrders[pos][2], ":", CurrentOrders[pos][2], "|", MasterOrders[pos][3], ":", CurrentOrders[pos][3]);
    pos++;
  }
  if (DebugLevel > 1) {
    if (rebuild) {
      Print (Symbol(), RunMode, "Unterschied bei MasterOrders(", anzahlMasterOrders, "):CurrentOrders(", anzahlCurrentOrders, ") Pos ", pos, ":", MathRound(LotFaktor*100*MathAbs(MasterOrders[pos][0]))/100, ":", CurrentOrders[pos][0], "|", MasterOrders[pos][1], ":", CurrentOrders[pos][1], "|", MasterOrders[pos][2], ":", CurrentOrders[pos][2], "|", MasterOrders[pos][3], ":", CurrentOrders[pos][3]);
      Print (Symbol(), RunMode, "Vergleiche Arrays Ergebnis: Rebuild: ", rebuild);
    }
  }
  
  return(rebuild);
}


//+------------------------------------------------------------------+
//| Kopiert die aktuellen Orders nach Masterorders                   |
//+------------------------------------------------------------------+ 
int copyCurrent2Master() {

  bool diff;

  if (DebugLevel > 1) Print (Symbol(), RunMode, "Übernehme aktuelle Orders nach Master Orders");
  for (int pos=0; pos<=anzahlCurrentOrders; pos++) {
    diff = false;
    for (int pos2=0; pos2<4; pos2++) {
      if (MasterOrders[pos][pos2] != CurrentOrders[pos][pos2]) {
        diff = true;
        MasterOrders[pos][pos2] = CurrentOrders[pos][pos2];
      }
    }
    if (DebugLevel > 0) {
      int SELLBUY;
      if (MasterOrders[pos][0] > 0) {
        SELLBUY = 0;
      } else {
        SELLBUY = 1;
      }
      if (diff) Print (Symbol(), RunMode, "Order[", pos, ",", MasterOrders[pos][3], "]:(", Symbol(), ", ", MathAbs(MasterOrders[pos][0]), "(", MathAbs(MathRound(LotFaktor*100*MasterOrders[pos][0])/100), "), ", MasterOrders[pos][1], ", ", MasterOrders[pos][2], ")");
    }
  }
  
  return(anzahlCurrentOrders);
}


//+------------------------------------------------------------------+
//| Masterorders auf Slave ausführen                                 |
//+------------------------------------------------------------------+ 
bool executeMasterOrders() {

  bool ok = true;
      
  int ticket = 0;    
  for (int pos=0; pos<anzahlMasterOrders; pos++) {
    // Falls eine Ticketnummer existiert, existiert bereits eine Order und diese wird modifiziert,
    // ansonsten wird die Order neu angelegt
    if (CurrentOrders[pos][3] != 0) {
      if (DebugLevel > 0) Print(Symbol(), RunMode, "OrderModify(", CurrentOrders[pos][3], ", 0, ", CurrentOrders[pos][2], ", ", CurrentOrders[pos][1], ", 0, CLR_NONE)");
      // OrderModify(CurrentOrders[pos][3], 0, CurrentOrders[pos][2], CurrentOrders[pos][1], 0, CLR_NONE);
    } else {
      int mode;
      if (MasterOrders[pos][0] < 0) mode = OP_SELL;
      else mode = OP_BUY;
      if (DebugLevel > 0) Print(Symbol(), RunMode, "OrderSend(", Symbol(), ", ", mode, ", ", MathRound(LotFaktor*100*MathAbs(MasterOrders[pos][0]))/100, ", ", Ask, ", 3,", CurrentOrders[pos][2], ", ", CurrentOrders[pos][1], ", Comment, ", MagicNumber, ", 0, CLR_NONE)");
      //ticket=OrderSend(Symbol(), mode, MathRound(LotFaktor*100*MathAbs(MasterOrders[pos][0]))/100, Ask, 3, CurrentOrders[pos][2], CurrentOrders[pos][1], "My order", MagicNumber, 0, CLR_NONE);
      if (ticket<0) {
        if (DebugLevel > 1) Print(Symbol(), " Slave: OrderSend failed with error #",GetLastError());
        ok = false;
      }
    }
  }

  return(ok);      
}