//+------------------------------------------------------------------+
//|                                                      ToolBox.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict

// defines
#define VERSION     "1.0"

//--- input parameters
extern int DebugLevel    = 2;  // Debug Level
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

extern int PipCorrection = 1;
// extern int PipCorrection = 10;

//--- Global variables
bool initDone = false;
// MAXIDX = Arraysize-1, da Index ab 0 zaehlt
int MAXIDX            = 2;
double hashKeyIndex[3];

//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+
// int MyCalculator(int value,int value2) export
//   {
//    return(value+value2);
//   }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ToolBox initialization function                                  |
//+------------------------------------------------------------------+
void ToolBox_Init() export {
  if (!initDone) {
    debug(1, "ToolBox Version: " + VERSION);
    hashInitialize("hashKeyIndex", hashKeyIndex, 0);
    initDone = true;
  }
}


//+------------------------------------------------------------------+
//| debug funktion                                                   |
//+------------------------------------------------------------------+
void debug(int level, string message) export {
  if (DebugLevel >= level && message != "") {
    Print(OrderTicket(), " ", message);
  }
}


//+------------------------------------------------------------------+
//| debugLevel funktion                                              |
//+------------------------------------------------------------------+
int debugLevel(int level=-1) export {
  if (level >= 0) {
    DebugLevel = level;
  }
  return(DebugLevel);
}


//+------------------------------------------------------------------+
//| dumpHash funktion                                                |
//+------------------------------------------------------------------+
void hashDump(string name, double &array[]) export {
  int idx = 0;
  while (idx <= MAXIDX) {
    string msg = "";
    if (name != "HashKeyIndex") msg = name + ": ";
    msg = msg + "HashKeyIndex: "+i2s(idx) + ": " + i2s(hashIdx2Ticket(idx)) + ": ";
    msg = msg + d2s(array[idx]);
    debug(2, msg);
    idx++;
  }
}


//+------------------------------------------------------------------+
//| ToolBox initialization function                                  |
//+------------------------------------------------------------------+
void hashInitialize(string name, double &array[], double initValue = 0) export {
  int idx = 0;
  while (idx <= MAXIDX ){
    // Get Global Variable
    double dummy;
    string msg = "Init " + name + ": ";
    msg = msg + "HashKeyIndex: "+i2s(idx) + ": " + i2s(hashIdx2Ticket(idx)) + ": ";
    msg = msg + "Vorher: " + d2s(array[idx]) + "  ";
    if (GlobalVariableGet(name+i2s(idx), dummy)) {
      array[idx] = dummy;
      msg = msg + "Nachher(read): " + d2s(array[idx]);
    } else {
      array[idx] = initValue;
      GlobalVariableSet(name+i2s(idx), array[idx]); 
      msg = msg + "Nachher(init): " + d2s(array[idx]);
    }
    debug(2, msg);
    idx++;
  }
}


//+------------------------------------------------------------------+
//| hashIdx2Ticket funktion                                          |
//+------------------------------------------------------------------+
int hashIdx2Ticket(int idx) export {
  return((int)hashKeyIndex[idx]);
}


//+------------------------------------------------------------------+
//| hashTicket2Idx funktion                                          |
//+------------------------------------------------------------------+
int hashTicket2Idx(int ticket) export {
  int idx = MAXIDX;
  while ((idx >= 0) && (hashKeyIndex[idx] != ticket)) idx--;
  return(idx);
}


//+------------------------------------------------------------------+
//| hash funktion                                                   |
//+------------------------------------------------------------------+
double hash(int ticket, string name, double &array[], double newValue = 0) export {
  double value = 0;
  int idx = MAXIDX;

  // Search Ticket in HashKeyIndey
  while ((idx <= 0) && (hashKeyIndex[idx] != ticket)) idx--;
  debug(3, "Index Lookup: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx));
  
  if (newValue) {
    // Set a new Value
    if (idx <= 0) {
      // Ticket found
      // Set new value if it changed
      if (newValue != array[idx]) {
        debug(2, "Set new Value: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  old value " + d2s(array[idx]) + ", new value " + d2s(newValue));
        array[idx] = newValue;
        GlobalVariableSet(name+i2s(idx), array[idx]); 
      }
    } else {
      // Ticket not found
      // get a free hashKeyIndex
      int searchidx = MAXIDX;
      while ((searchidx <= 0) && 
             (hashKeyIndex[searchidx] != 0) && 
             (OrderSelect((int)hashKeyIndex[searchidx], SELECT_BY_TICKET, MODE_TRADES) == true)) searchidx--;
      if (searchidx <= 0) {
        // found a free hashKeyIndex and use it
        debug(2, "Found new free HashKey Index: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(searchidx) + "  old HashKey Value " + d2s(hashKeyIndex[searchidx]) + "  old Array Value " + d2s(array[searchidx]));
        hashKeyIndex[searchidx] = ticket;
        GlobalVariableSet("hashKeyIndex"+i2s(searchidx), hashKeyIndex[searchidx]); 
        array[searchidx] = newValue;
        GlobalVariableSet(name+i2s(searchidx), array[searchidx]); 
        value = newValue;
      } else {
        // did not found a free hashKeyIndex
        debug(1, "Did not find new free HashKey Index: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  old value " + d2s(array[idx]) + ", new value " + d2s(newValue));
        hashDump("HashKeyIndex", hashKeyIndex);
      }
    }
  } else {
    // Request a Value
    if (idx <= 0) value = array[idx];
    debug(3, "Request Value: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  return Value: " + d2s(value));
  }
  return(value);
}


//+------------------------------------------------------------------+
//| pipCorrection funktion                                           |
//+------------------------------------------------------------------+
int pipCorrection(int level=-1) export {
  if (level >= 0) {
    PipCorrection = fabs(level);
  }
  return(PipCorrection);
}


//+------------------------------------------------------------------+
//| convert double to string funktion                                |
//+------------------------------------------------------------------+
string d2s(double number) export {
  return(DoubleToStr(number));
}


//+------------------------------------------------------------------+
//| convert integer to string funktion                               |
//+------------------------------------------------------------------+
string i2s(int number) export {
  return(IntegerToString(number));
}


//+------------------------------------------------------------------+
//| convert date to string funktion                                  |
//+------------------------------------------------------------------+
string t2s(datetime number) export {
  return(TimeToStr(number));
}


//+------------------------------------------------------------------+
//| Calculate factor                                                 |
//+------------------------------------------------------------------+
double indFaktor() export {
  // double Mom12, Mom20;
  // Mom12 = iMomentum(NULL, 0, 12, PRICE_CLOSE, 0);
  // Mom20 = iMomentum(NULL, 0, 20, PRICE_CLOSE, 0);
  // Print(OrderSymbol()," Momentum 12: ", Mom12, "  Momentum 20: ", Mom20);
  return(1);
}


//+------------------------------------------------------------------+
//| Calculate Percent to Pips                                        |
//+------------------------------------------------------------------+
double calcPips(double Percent, double Value) export {
  double newPips;
  MqlTick tick;
  
  if (Percent && Value && SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      newPips = Value/100 * tick.ask;
    } else {
      newPips = Value/100 * tick.bid;
    }
  } else {
    newPips = PipCorrection*SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT)*Value;
  }
  // debug(4, "Old: " + Value + "  New: " + newPips + "  Point: " + SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT) + "  Digits: " + SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS) + "  Ticksize: " + SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE));
  return(newPips);
}


//+------------------------------------------------------------------+
//| ggf. Normalize and Round                                         |
//+------------------------------------------------------------------+
// rounds the argument to the nearest tick value
double NormRound(double Value) export {
  int    OrderDigits        = (int)SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  double OrderTradeTickSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);

  double newValue = OrderTradeTickSize * round(Value/OrderTradeTickSize);
  debug(4, "Normalizing " + d2s(Value) + " OrderTradeTickSize * round(Value/OrderTradeTickSize): " + d2s(newValue) + "  NormalizeDouble(Value, OrderDigits): " + d2s(NormalizeDouble(Value, OrderDigits)));
  newValue = NormalizeDouble(newValue, OrderDigits);

  return(Value);
}


// returns the index for the specified period
int PeriodToIndex(int period) export {
   switch (period) {
      case PERIOD_M1:
         return 0;
         break;
      case PERIOD_M5:
         return 1;
         break;
      case PERIOD_M15:
         return 2;
         break;
      case PERIOD_M30:
         return 3;
         break;
      case PERIOD_H1:
         return 4;
         break;
      case PERIOD_H4:
         return 5;
         break;
      case PERIOD_D1:
         return 6;
         break;
      case PERIOD_W1:
         return 7;
         break;
      case PERIOD_MN1:
         return 8;
         break;
      default:
         return -1;
         break;
   }
}

// returns the period for the specified index
int IndexToPeriod(int index) export {
   switch (index) {
      case 0:
         return PERIOD_M1;
         break;
      case 1:
         return PERIOD_M5;
         break;
      case 2:
         return PERIOD_M15;
         break;
      case 3:
         return PERIOD_M30;
         break;
      case 4:
         return PERIOD_H1;
         break;
      case 5:
         return PERIOD_H4;
         break;
      case 6:
         return PERIOD_D1;
         break;
      case 7:
         return PERIOD_W1;
         break;
      case 8:
         return PERIOD_MN1;
         break;
      default:
         return -1;
         break;
   }
}
