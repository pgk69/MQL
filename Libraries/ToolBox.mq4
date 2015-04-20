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
double hashKeyIndex[101];

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
    debug(1, "ToolBox_Init: ToolBox Version: " + VERSION);
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
  int maxidx = ArraySize(array)-1;
  while (idx <= maxidx){
    string msg = "";
    if (name != "HashKeyIndex") msg = name + ": ";
    msg = msg + "HashKeyIndex: "+i2s(idx) + ": " + i2s(hashIdx2Ticket(idx)) + ": ";
    msg = msg + d2s(array[idx]);
    debug(2, "hashDump: " + msg);
    idx++;
  }
}


//+------------------------------------------------------------------+
//| ToolBox initialization function                                  |
//+------------------------------------------------------------------+
void hashInitialize(string name, double &array[], double initValue = 0) export {
  int idx = 0;
  int maxidx = ArraySize(array)-1;
  while (idx <= maxidx){
    // Get Global Variable
    double dummy;
    double vorher = array[idx];
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
    if (NormalizeDouble(vorher-array[idx], 5) > 0) debug(2, "hashInitialize: " + msg);
    idx++;
  }
  GlobalVariablesFlush();
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
  int idx = ArraySize(hashKeyIndex)-1;
  while ((idx >= 0) && (hashKeyIndex[idx] != ticket)) idx--;
  return(idx);
}


//+------------------------------------------------------------------+
//| hash funktion                                                   |
//+------------------------------------------------------------------+
double hash(int ticket, string name, double &array[], double newValue = 0) export {
  double value = 0;
  int idx = ArraySize(array)-1;

  // Search Ticket in HashKeyIndey
  while ((idx >= 0) && (NormalizeDouble(MathAbs(hashKeyIndex[idx]-ticket), 5) > 0)) idx--;
  debug(3, "hash: Index Lookup: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx));
  
  if (newValue) {
    // Set a new Value
    if (idx >= 0) {
      // Ticket found
      // Set new value if it changed
      if (NormalizeDouble(MathAbs(newValue-array[idx]), 5) != 0) {
        debug(2, "hash: Set new Value: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  old value " + d2s(array[idx]) + ", new value " + d2s(newValue));
        array[idx] = newValue;
        GlobalVariableSet(name+i2s(idx), array[idx]); 
      }
    } else {
      // Ticket not found
      // get a free hashKeyIndex
      int searchidx = ArraySize(array)-1;
      while ((searchidx >= 0) && 
             (hashKeyIndex[searchidx] != 0) && 
             (OrderSelect((int)hashKeyIndex[searchidx], SELECT_BY_TICKET) == true) &&
             (NormalizeDouble(OrderCloseTime(), 5) == 0)) searchidx--;
      if (searchidx >= 0) {
        // found a free hashKeyIndex and use it
        debug(2, "hash: Found new free HashKey Index: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(searchidx) + "  old HashKey Value " + d2s(hashKeyIndex[searchidx]) + "  old Array Value " + d2s(array[searchidx]));
        hashKeyIndex[searchidx] = ticket;
        GlobalVariableSet("hashKeyIndex"+i2s(searchidx), hashKeyIndex[searchidx]); 
        array[searchidx] = newValue;
        GlobalVariableSet(name+i2s(searchidx), array[searchidx]); 
        value = newValue;
      } else {
        // did not found a free hashKeyIndex
        debug(1, "hash: Did not find new free HashKey Index: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  Searchindex: " + i2s(searchidx) + ", new value " + d2s(newValue));
        hashDump("HashKeyIndex", hashKeyIndex);
      }
    }
  } else {
    // Request a Value
    if (idx >= 0) value = array[idx];
    debug(3, "hash: Request Value: Array: " + name + "  Ticket: " + i2s(ticket) + "  Index: " + i2s(idx) + "  return Value: " + d2s(value));
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
double calcPips(double Percent, double Value, string OS = "") export {
  double newPips;
  MqlTick tick;
  if (OS == "") OS = OrderSymbol();
  
  if (Percent && Value && SymbolInfoTick(OS, tick)) {
    if (OrderType() == OP_BUY) {
      newPips =  NormRound(Value/100 * tick.ask);
    } else {
      newPips =  NormRound(Value/100 * tick.bid);
    }
  } else {
    newPips =  NormRound(PipCorrection*SymbolInfoDouble(OS, SYMBOL_POINT)*Value);
  }
  // debug(4, "calcPips: Old: " + Value + "  New: " + newPips + "  Point: " + SymbolInfoDouble(OS, SYMBOL_POINT) + "  Digits: " + SymbolInfoInteger(OS, SYMBOL_DIGITS) + "  Ticksize: " + SymbolInfoDouble(OS, SYMBOL_TRADE_TICK_SIZE));
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
  debug(4, "NormRound: Normalizing " + d2s(Value) + " OrderTradeTickSize * round(Value/OrderTradeTickSize): " + d2s(newValue) + "  NormalizeDouble(Value, OrderDigits): " + d2s(NormalizeDouble(newValue, OrderDigits)));
  newValue = NormalizeDouble(newValue, OrderDigits);

  return(newValue);
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
