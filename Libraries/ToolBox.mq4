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

//--- input parameters
extern int DebugLevel           = 2;  // Debug Level
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

extern int PipCorrection            = 1;
// extern int PipCorrection            = 10;

//--- Global variables

//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+
// int MyCalculator(int value,int value2) export
//   {
//    return(value+value2);
//   }
//+------------------------------------------------------------------+


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
//| pipCorrection funktion                                           |
//+------------------------------------------------------------------+
int pipCorrection(int level=-1) export {
  if (level >= 0) {
    PipCorrection = fabs(level);
  }
  return(PipCorrection);
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
  int    OrderDigits        = SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  double OrderTradeTickSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);

  double newValue = OrderTradeTickSize * round(Value/OrderTradeTickSize);
  debug(4, "Normalizing " + Value + " OrderTradeTickSize * round(Value/OrderTradeTickSize): " + newValue + "  NormalizeDouble(Value, OrderDigits): " + NormalizeDouble(Value, OrderDigits));
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
