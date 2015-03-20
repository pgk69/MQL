//+------------------------------------------------------------------+
//|                                               ExitStrategies.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict

#include <ToolBox.mqh>

//--- input parameters
// common

//--- Global variables
bool initDone = false;
int strategy[101];
double StopLossVal[101];
double TakeProfitVal[101];
double Active_Arr[101];
bool Active = 0;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
void ExitStrategies_Init() export {
  if (!initDone) {
    ToolBox_Init();
    debug(1, "ExitStrategies Version: " + VERSION);
    ArrayInitialize(strategy, true);
    hashInitialize("Active", Active_Arr,    -1);
    hashInitialize("SL",     StopLossVal,    0);
    hashInitialize("TP",     TakeProfitVal,  0);
    initDone = true;
  }
}


//+------------------------------------------------------------------+
//| TP/SL strategy activation function                               |
//+------------------------------------------------------------------+
int ExitStrategieStatus(string strategie, bool On) export {
  int rc = -1;
  int idx = -1;
  
  if (strategie == "InitialTP")     idx = 0;
  if (strategie == "TrailingTP")    idx = 1;
  if (strategie == "Initial")       idx = 2;
  if (strategie == "Trailing")      idx = 3;
  if (strategie == "N-Bar")         idx = 4;
  if (strategie == "Steps")         idx = 5;
  if (strategie == "D-Steps")       idx = 6;
  
  if (strategie == "FollowUpOrder") idx = 100;

  if (idx >= 0) {
    if (On == 1 || On == 0) strategy[idx] = On;
    rc = strategy[idx];
    string OnOff = rc ? "On" : "Off";
    debug(1, "ExitStrategie " + strategie + " (" + i2s(idx) + ") " + OnOff);
  }
  return(rc);
}


//+------------------------------------------------------------------+
//| Check whether Trade is already known function                    |
//+------------------------------------------------------------------+
void checkTrade(int ticket, double TPPips, double SLPips) export {
  if (hashTicket2Idx(ticket) < 0) {
    hash(OrderTicket(), "Active", Active_Arr,        -1);
    hash(OrderTicket(), "SL",     StopLossVal,   SLPips);
    hash(OrderTicket(), "TP",     TakeProfitVal, TPPips);
  }
}


//+------------------------------------------------------------------+
//| determine whether SL is activ                                    |
//+------------------------------------------------------------------+
bool SL_is_active(int ticket) export {

  return (hash(ticket, "Active", Active_Arr) > 0) ? 1 : 0;
  
//  int rc = (int)hash(OrderTicket(), "Active", Active_Arr);
//
//  if (rc < 0) {
//    bool SThChanged = false;
//    double TPSL;
//    TPSL = hash(OrderTicket(), "TP", TakeProfitVal);
//    if (NormalizeDouble(TPSL, 5) == 0) {
//      if (NormalizeDouble(OrderTakeProfit(), 5) != 0) hash(OrderTicket(), "SL", TakeProfitVal, OrderTakeProfit());
//    } else {
//      if (NormalizeDouble(OrderTakeProfit()-TPSL, 5) != 0) {
//        SThChanged = true;
//      }
//    }
// 
//    TPSL = hash(OrderTicket(), "SL", StopLossVal);
//    if (NormalizeDouble(TPSL, 5) == 0) {
//      if (NormalizeDouble(OrderStopLoss(), 5) != 0) hash(OrderTicket(), "SL", StopLossVal, OrderStopLoss());
//    } else {
//      if (NormalizeDouble(OrderStopLoss()-TPSL, 5) != 0) {
//        SThChanged = true;
//      }
//    }
//    
//    if (SThChanged) {
//      rc = 1;
//      hash(OrderTicket(), "Active", Active_Arr, 1);
//      debug(3, "SL Activation: Ticket: " + i2s(OrderTicket()));
//    }
//  }
//  
//  return(rc>0 ? 1 : 0);
}


//+------------------------------------------------------------------+
//| determine TP                                                     |
//+------------------------------------------------------------------+
double TakeProfit(int ticket, string &message, double TP, double TPPips, double TPTrailPips, double Correction) export {
  double newTP = TP;
  string detail;
  detail = initial_TP(newTP, TPPips);
  if (detail != "") {
    debug(2, detail);
    message = "initial ";
  }
  detail = trailing_TP(newTP, TPPips, TPTrailPips, Correction);
  if (detail != "") {
    debug(2, detail);
    message = "trailing ";
  }

  if (NormalizeDouble(TP, 5) == 0) {
    // New Trade or resettet manually
    hash(ticket, "Activ", Active_Arr, 0);
  } else if (NormalizeDouble(newTP-TP, 5) != 0) {
    // Existing Trade got new TP -> activte SL
    hash(ticket, "Activ", Active_Arr, 1);
  }

  return(newTP);
}


//+------------------------------------------------------------------+
//| determine SL                                                     |
//+------------------------------------------------------------------+
double StopLoss(int ticket, string &message, double SL, double TPPips, double SLPips, double SLTrailPips, double Correction, int timeframe, int barCount, double timeframeFaktor, double SLStepsPips, double SLStepsDist) export {
  double newSL = SL;
  debug(2, initial_SL(newSL, SLPips));
  string detail = initial_SL(newSL, SLPips);
  if (detail != "") {
    debug(2, detail);
    message = "initial ";
  }
  
  if ((NormalizeDouble(SL, 5) != 0) && hash(ticket, "Activ", Active_Arr)) {

    // ID 3: Trailing SL
    double SL1 = SL;
    string message1 = "";
    if (strategy[3]) {
      message1 = trailing_SL(SL1, SLPips, SLTrailPips, Correction);
      newSL = (OrderType() == OP_BUY) ? fmax(newSL, SL1): fmin(newSL, SL1);
      debug(3, "Trailing SL newSL: " + d2s(newSL));
    }

    // ID 4: N-Bar SL
    double SL2 = SL;
    string message2 = "";
    if (strategy[4]) {
      message2 = N_Bar_SL(SL2, SLPips, timeframe, barCount, timeframeFaktor);
      newSL = (OrderType() == OP_BUY) ? fmax(newSL, SL2): fmin(newSL, SL2);
      debug(3, "N-Bar newSL: " + d2s(newSL));
    }

    // ID 5: Steps SL
    double SL3 = SL;
    string message3 = "";
    if (strategy[5]) {
      message3 = Steps_SL(SL3, SLStepsPips, SLStepsDist);
      newSL = (OrderType() == OP_BUY) ? fmax(newSL, SL3): fmin(newSL, SL3);
      debug(3, "Steps newSL: " + d2s(newSL));
    }
 
    // ID 6: D-Steps SL
    double SL4 = SL;
    string message4 = "";
    if (strategy[6]) {
//      message4 = DSteps_SL(SL4, SLStepsPips, SLStepsDist);
//      newSL = (OrderType() == OP_BUY) ? fmax(newSL, SL4): fmin(newSL, SL4);
//      debug(3, "D-Steps newSL: " + newSL);
    }
 
    if ((NormalizeDouble(newSL-SL1, 5) == 0) && (NormalizeDouble(SL-SL1, 5) != 0)) {
      message = message + "trailing ";
      debug(2, message1);
    }
    if ((NormalizeDouble(newSL-SL2, 5) == 0) && (NormalizeDouble(SL-SL2, 5) != 0)) {
      message = message + "N-Bar ";
      debug(2, message2);
    }
    if ((NormalizeDouble(newSL-SL3, 5) == 0) && (NormalizeDouble(SL-SL3, 5) != 0)) {
      message = message + "Steps ";
      debug(2, message3); 
    }
    if ((NormalizeDouble(newSL-SL4, 5) == 0) && (NormalizeDouble(SL-SL4, 5) != 0)) {
      message = message + "D-Steps ";
      debug(2, message4); 
    }
  }
  return(newSL);
}


// when I buy  long  I get the ask price
// when I sell long  I get the bid price
// when I buy  short I get the bid price
// when I sell short I get the ask price
//+------------------------------------------------------------------+
//| determine initial TP  ID:0                                       |
//+------------------------------------------------------------------+
string initial_TP(double &TP, double TPPips) export {
  int ID = 0;
  MqlTick tick;
  double newTP = TP;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(TP, 5) == 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newTP = NormRound(tick.bid + TPPips);
        }
        if (OrderType() == OP_SELL) {
          newTP = NormRound(tick.ask - TPPips);
        }
    
        if (NormalizeDouble(newTP-TP, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "initial TakeProfit " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " initial: " + d2s(newTP);
          debug(3, message);
          TP = newTP;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine trailing TP  ID: 1                                     |
//+------------------------------------------------------------------+
string trailing_TP(double &TP, double TPPips, double TPTrailPips, double Correction) export {
  int ID = 1;
  MqlTick tick;
  double newTP = TP;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(TP, 5) != 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newTP = fmax(TP, NormRound(tick.bid + Correction*TPTrailPips)); // TP will never be decreased
        }
        if (OrderType() == OP_SELL) {
          newTP = fmin(TP, NormRound(tick.ask - Correction*TPTrailPips)); // TP will never be increased
        }
    
        if (NormalizeDouble(newTP-TP, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "trailing TakeProfit " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " old: " + d2s(TP) + " new: " + d2s(newTP);
          debug(3, message);
          TP = newTP;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine initial SL  ID: 2                                      |
//+------------------------------------------------------------------+
string initial_SL(double &SL, double SLPips) export {
  int ID = 2;
  MqlTick tick;
  double newSL = SL;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(SL, 5) == 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newSL = NormRound(tick.bid - SLPips);
        }
        if (OrderType() == OP_SELL) {
          newSL = NormRound(tick.ask + SLPips);
        }
        if (NormalizeDouble(newSL-SL, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "initial StopLoss " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " initial: " + d2s(newSL);
          debug(3, message);
          SL = newSL;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine trailing SL  ID: 3                                     |
//+------------------------------------------------------------------+
string trailing_SL(double &SL, double SLPips, double SLTrailPips, double Correction) export {
  int ID = 3;
  MqlTick tick;
  double newSL = SL;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(SL, 5) == 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newSL = fmax(SL, NormRound(tick.bid - SLTrailPips));
        }
        if (OrderType() == OP_SELL) {
          newSL = fmin(SL, NormRound(tick.ask + SLTrailPips));
        }
        if (NormalizeDouble(newSL-SL, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "trailing StopLoss " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " old: " + d2s(SL) + " new: " + d2s(newSL);
          debug(3, message);
          SL = newSL;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine N-Bar SL  ID: 4                                        |
//+------------------------------------------------------------------+
string N_Bar_SL(double &SL, double SLPips, int timeframe, int barCount, double timeframeFaktor) export {
  int ID = 4;
  MqlTick tick;
  double newSL = SL;
  
  string message = "";
  if (strategy[ID]) {
    double barTime = 0;
    if (timeframe < 0) {
      // no timeframe is given, so we decide outselfs
      // based on how long the order is activ
      barTime = round((TimeCurrent()-OrderOpenTime())/barCount);
      if      (barTime <     300*timeframeFaktor) timeframe = PERIOD_M1;
      else if (barTime <     900*timeframeFaktor) timeframe = PERIOD_M5;
      else if (barTime <    1800*timeframeFaktor) timeframe = PERIOD_M15;
      else if (barTime <    3600*timeframeFaktor) timeframe = PERIOD_M30;
      else if (barTime <   14400*timeframeFaktor) timeframe = PERIOD_H1;
      else if (barTime <   86400*timeframeFaktor) timeframe = PERIOD_H4;
      else if (barTime <  604800*timeframeFaktor) timeframe = PERIOD_D1;
      else if (barTime < 2678400*timeframeFaktor) timeframe = PERIOD_W1;
      else                                        timeframe = PERIOD_MN1;
    }

    if (NormalizeDouble(SL, 5) != 0) { // only if it's not an initial
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          double Min_N_Bar = 1000000000;
          int i = barCount;
          while (i>0) Min_N_Bar = fmin(Min_N_Bar, iLow(OrderSymbol(), timeframe, i--));
          newSL = fmax(SL, Min_N_Bar);
          debug(4, "fmax(SL=" + d2s(SL) + " + Min_N_Bar=" + d2s(Min_N_Bar) + ")=" + d2s(newSL));
        }
        if (OrderType() == OP_SELL) {
          double Max_N_Bar = -1000000000;
          int i = barCount;
          while (i>0) Max_N_Bar = fmax(Max_N_Bar, iHigh(OrderSymbol(), timeframe, i--));
          newSL = fmin(SL, Max_N_Bar);
          debug(4, "fmin(SL=" + d2s(SL) + ", Max_N_Bar=" + d2s(Max_N_Bar) + ")=" + d2s(newSL));
        }
        if (NormalizeDouble(newSL-SL, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = i2s(barCount) + "-Bar StopLoss (Periode: " + i2s(timeframe) + "/" + d2s(barTime) + "/" + d2s(timeframeFaktor) + ") " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " old: " + d2s(SL) + " new: " + d2s(newSL);
          debug(3, message);
          SL = newSL;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine Steps SL  ID: 5                                        |
//+------------------------------------------------------------------+
 string Steps_SL(double &SL, double SLStepsPips, double SLStepsDist) export {
  int ID = 5;
  MqlTick tick;
  double newSL = SL;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(SL, 5) != 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          double Step = floor((tick.bid - OrderOpenPrice() - SLStepsDist)/SLStepsPips);
          newSL = fmax(SL, NormRound(OrderOpenPrice() + Step*SLStepsPips));
        }
        if (OrderType() == OP_SELL) {
          double Step = floor((OrderOpenPrice() - tick.ask - SLStepsDist)/SLStepsPips);
          newSL = fmin(SL, NormRound(OrderOpenPrice() - Step*SLStepsPips));
        }
        if (NormalizeDouble(newSL-SL, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "Steps StopLoss " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " old: " + d2s(SL) + " new: " + d2s(newSL);
          debug(3, message);
          SL = newSL;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine D-Steps SL  ID: 6                                      |
//+------------------------------------------------------------------+
 string DSteps_SL(double &SL, double &steps[]) export {
  int ID = 5;
  MqlTick tick;
  double newSL = SL;

  string message = "";
  if (strategy[ID]) {
    if (NormalizeDouble(SL, 5) != 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
//          double Step = floor((tick.bid - OrderOpenPrice() - SLStepsDist)/SLStepsPips);
//          newSL = fmax(SL, NormRound(OrderOpenPrice() + Step*SLStepsPips));
        }
        if (OrderType() == OP_SELL) {
//          double Step = floor((OrderOpenPrice() - tick.ask - SLStepsDist)/SLStepsPips);
//          newSL = fmin(SL, NormRound(OrderOpenPrice() - Step*SLStepsPips));
        }
        if (NormalizeDouble(newSL-SL, 5) != 0) {
          string longShort = OrderType() ? "short" : "long";
          message = "Steps StopLoss " + longShort + " Order (" + i2s(OrderTicket()) + "): Buyprice: " + d2s(OrderOpenPrice()) + " Bid/Ask: " + d2s(tick.bid) + "/" + d2s(tick.ask) + " old: " + d2s(SL) + " new: " + d2s(newSL);
          debug(3, message);
          SL = newSL;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| FollowUp Order  ID: 100                                          |
//+------------------------------------------------------------------+
int followUpOrder(int ticketID, int expiry) export {
  int ID = 100;

  int rc = 0;
  if (strategy[ID]) {
    if (OrderSelect(ticketID, SELECT_BY_TICKET)) {
      string mySymbol   = OrderSymbol();
      double myLots     = OrderLots();
      double myPrice    = OrderOpenPrice();
      int    myMagic    = OrderMagicNumber();
      int    limit_type = (OrderType() == OP_SELL) ? OP_SELLLIMIT : OP_BUYLIMIT;
      string comment    = "Ref:" + i2s(ticketID);
      string originalTrade = "followUpOrder: Original Order: TicketID: " + i2s(ticketID) + "  Symbol: " + mySymbol + "  Lots: " + d2s(myLots) + "  Price: " + d2s(myPrice) + "  Magic: " + i2s(myMagic) + "  Type: " + i2s(limit_type) + "  Comment: " + comment; 
      myLots = myLots/2;
      bool found = false;
      for (int i=0; i<OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; // Only valid Tickets are processed
        if (myMagic && (OrderMagicNumber() != myMagic))  continue; // according to MagicNumber only tickets with fitting magicnumber are processed
        found |= (StringFind(OrderComment(), comment)>=0);         // Source Order is not referenced
        if (found) break;
      }
      if (!found) {
        rc = OrderSend(mySymbol, limit_type, myLots, myPrice, 3, 0, 0, comment, myMagic, TimeCurrent() + expiry, clrNONE);
        debug(3, originalTrade);
        debug(2, "followUpOrder: OrderSend (" + mySymbol + ", " + i2s(limit_type) + ", " + d2s(myLots) + ", " + d2s(myPrice) + ", 3, 0, 0, " + comment + ", " + i2s(myMagic) + ", " + d2s(TimeCurrent() + expiry) + ", CLR_NONE): " + i2s(rc));
      }
    }
  }
  return(rc);
}
//+------------------------------------------------------------------+
