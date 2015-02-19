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
int strategy[6];
string message;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
void ExitStrategies_Init() export {
  debug(1, StringConcatenate("ExitStrategies Version: ", VERSION));
  ExitStrategie("InitialTP",     1);
  ExitStrategie("TrailingTP",    1);
  ExitStrategie("Initial",       1);
  ExitStrategie("Trailing",      1);
  ExitStrategie("N-Bar",         1);
  ExitStrategie("FollowUpOrder", 1);
}


//+------------------------------------------------------------------+
//| TP/SL strategy activation function                               |
//+------------------------------------------------------------------+
int ExitStrategie(string strategie, int On) export {
  int rc = -1;
  int idx = -1;
  
  if (strategie == "InitialTP")     idx = 0;
  if (strategie == "TrailingTP")    idx = 1;
  if (strategie == "Initial")       idx = 2;
  if (strategie == "Trailing")      idx = 3;
  if (strategie == "N-Bar")         idx = 4;
  if (strategie == "FollowUpOrder") idx = 5;

  if (idx >= 0) {
    if (On == 1 || On == 0) strategy[idx] = On;
    rc = strategy[idx];
    debug(1, StringConcatenate("ExitStrategie ", strategie, " (", idx, ") is turned ", rc));
  }
  return(rc);
}


//+------------------------------------------------------------------+
//| determine whether SL is activ                                    |
//+------------------------------------------------------------------+
bool SL_active(double TPPips, double SLPips) {
  double deltaTP = 0;
  double deltaSL = 0;

  if (OrderType() == OP_BUY) {
    deltaTP = OrderTakeProfit() - (OrderOpenPrice()+TPPips);
    deltaSL = OrderStopLoss()   - (OrderOpenPrice()-SLPips);
  }
  if (OrderType() == OP_SELL) {
    deltaTP = (OrderOpenPrice()-TPPips) - OrderTakeProfit();
    deltaSL = (OrderOpenPrice()+SLPips) - OrderStopLoss();
  }

  bool SLActiv = (deltaTP > 0) || (deltaSL > 0);
  debug(3, StringConcatenate("SL Activation: ", SLActiv, " (DeltaTP: ", deltaTP, "  DeltaSL: ", deltaSL, ")"));
  
  return(SLActiv);
}


//+------------------------------------------------------------------+
//| determine TP                                                     |
//+------------------------------------------------------------------+
double TP(double TP, double TPPips, double TPTrailPips, double Correction, bool& initialTP, bool& resetTP) export {
  double newTP = TP;
  debug(2, initial_TP(newTP, TPPips, initialTP));
  debug(2, trailing_TP(newTP, TPPips, TPTrailPips, Correction, initialTP, resetTP));
  return(newTP);
}


//+------------------------------------------------------------------+
//| determine SL                                                     |
//+------------------------------------------------------------------+
double SL(double SL, double TPPips, double SLPips, double SLTrailPips, double Correction, bool& initialSL, bool& resetSL, bool resetTP, int timeframe, int barCount, double timeframeFaktor, int ticketID, int expirys) export {
  double newSL = SL;
  debug(2, initial_SL(newSL, SLPips, initialSL));
  if (!initialSL && SL_active(TPPips, SLPips)) {
    double SL1 = SL;
    string message1 = trailing_SL(SL1, SLPips, SLTrailPips, Correction, initialSL, resetSL, resetTP);
    newSL = (OrderType() == OP_BUY) ? fmin(newSL, SL1): fmax(newSL, SL1);
    double SL2 = SL;
    string message2 = N_Bar_SL(SL2, SLPips, initialSL, resetSL, resetTP, timeframe, barCount, timeframeFaktor);
    newSL = (OrderType() == OP_BUY) ? fmin(newSL, SL2): fmax(newSL, SL2);

    if ((newSL == SL1) && (SL != SL1)) debug(2, message1);
    if ((newSL == SL2) && (SL != SL2)) debug(2, message2);
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
string initial_TP(double& TP, double TPPips, bool& initialTP) export {
  int ID = 0;
  MqlTick tick;
  double newTP = TP;

  message = "";
  initialTP = false;
  if (strategy[ID]) {
    if (TP == 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newTP = NormRound(tick.bid + TPPips);
        }
        if (OrderType() == OP_SELL) {
          newTP = NormRound(tick.ask - TPPips);
        }
    
        if (newTP != TP) {
          message = StringConcatenate("initial TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newTP);
          debug(3, message);
          TP = newTP;
          initialTP = true;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine trailing TP  ID: 1                                     |
//+------------------------------------------------------------------+
string trailing_TP(double& TP, double TPPips, double TPTrailPips, double Correction, bool& initialTP, bool& resetTP) export {
  int ID = 1;
  MqlTick tick;
  double newTP = TP;
  double newTPTrail;

  message = "";
  resetTP = false;
  if (strategy[ID]) {
    if (TP != 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newTPTrail = NormRound(tick.bid + Correction*TPTrailPips);
          newTP      = fmax(TP, newTPTrail);                           // TP will never be decreased
        }
        if (OrderType() == OP_SELL) {
          newTPTrail = NormRound(tick.ask - Correction*TPTrailPips);
          newTP      = fmin(TP, newTPTrail);                           // TP will never be increased
        }
    
        if (newTP != TP) {
          message = StringConcatenate("trailing TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", TP, " new: ", newTP);
          debug(3, message);
          TP = newTP;
          resetTP = true;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine initial SL  ID: 2                                      |
//+------------------------------------------------------------------+
string initial_SL(double& SL, double SLPips, bool& initialSL) export {
  int ID = 2;
  MqlTick tick;
  double newSL = SL;

  message = "";
  initialSL = false;
  if (strategy[ID]) {
    if (SL == 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          newSL = NormRound(tick.bid - SLPips);
        }
        if (OrderType() == OP_SELL) {
          newSL = NormRound(tick.ask + SLPips);
        }
        if (newSL != SL) {
          message = StringConcatenate("initial StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newSL);
          debug(3, message);
          SL = newSL;
          initialSL = true;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine trailing SL  ID: 3                                     |
//+------------------------------------------------------------------+
string trailing_SL(double& SL, double SLPips, double SLTrailPips, double Correction, bool& initialSL, bool& resetSL, bool resetTP) export {
  int ID = 3;
  MqlTick tick;
  double newSL = SL;

  message = "";
  resetSL = false;
  if (strategy[ID]) {
    if (SL != 0) {
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          if (resetTP) {  // Increase Trailing SL if TP was increased; SL will never be decreased
            newSL = fmax(SL, NormRound(tick.bid - SLTrailPips));
          }
        }
        if (OrderType() == OP_SELL) {
          if (resetTP) {  // Decrease Trailing SL if TP was decreased; SL will never be increased
            newSL = fmin(SL, NormRound(tick.ask + SLTrailPips));
          }
        }
        if (newSL != SL) {
          message = StringConcatenate("trailing StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", SL, " new: ", newSL);
          debug(3, message);
          SL = newSL;
          resetSL = true;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| determine N-Bar SL  ID: 4                                        |
//+------------------------------------------------------------------+
string N_Bar_SL(double SL, double SLPips, bool& initialSL, bool& resetSL, bool resetTP, int timeframe, int barCount, double timeframeFaktor) export {
  int ID = 4;
  MqlTick tick;
  double newSL = SL;
  
  message = "";
  resetSL = false;
  if (strategy[ID]) {
    int barTime = 0;
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

    if (SL != 0) {  // only if it's not an initial
      if (SymbolInfoTick(OrderSymbol(), tick)) {
        if (OrderType() == OP_BUY) {
          double Min_N_Bar = 1000000000;
          int i = barCount;
          while (i>0) Min_N_Bar = fmin(Min_N_Bar, iLow(OrderSymbol(), timeframe, i--));
          newSL = fmax(SL, Min_N_Bar);
          debug(4, StringConcatenate("fmax(SL=", SL, ", Min_N_Bar=", Min_N_Bar, ")=", newSL));
        }
        if (OrderType() == OP_SELL) {
          double Max_N_Bar = -1000000000;
          int i = barCount;
          while (i>0) Max_N_Bar = fmax(Max_N_Bar, iHigh(OrderSymbol(), timeframe, i--));
          newSL = fmin(SL, Max_N_Bar);
          debug(4, StringConcatenate("fmin(SL=", SL, ", Max_N_Bar=", Max_N_Bar, ")=", newSL));
        }
        if (newSL != SL) {
          message = StringConcatenate(barCount, "-Bar StopLoss (Periode: ", timeframe, "/", barTime, "/", timeframeFaktor, ") ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", SL, " new: ", newSL);
          debug(3, message);
          SL = newSL;
          resetSL = true;
        }
      }
    }
  }

  return(message);
}


//+------------------------------------------------------------------+
//| FollowUp Order  ID: 5                                            |
//+------------------------------------------------------------------+
int followUpOrder(int ticketID, int expiry) export {
  int ID = 5;

  int rc = 0;
  if (strategy[ID]) {
    if (OrderSelect(ticketID, SELECT_BY_TICKET, MODE_TRADES)) {
      string mySymbol   = OrderSymbol();
      double myLots     = OrderLots();
      double myPrice    = OrderOpenPrice();
      int    myMagic    = OrderMagicNumber();
      int    limit_type = (OrderType() == OP_SELL) ? OP_SELLLIMIT : OP_BUYLIMIT;
      string comment    = StringConcatenate("Ref:", ticketID);
      string originalTrade = StringConcatenate("followUpOrder: Original Order: TicketID: ", ticketID, "  Symbol: ", mySymbol, "  Lots: ", myLots, "  Price: ", myPrice, "  Magic: ", myMagic, "  Type: ", limit_type, "  Comment: ", comment); 
      myLots = myLots/2;
      bool found = false;
      for (int i=0; i<OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; // Only valid Tickets are processed
        if (OrderType() != limit_type)                   continue; // Only OP_BUY or OP_SELL Tickets are processed
        if (myMagic && (OrderMagicNumber() != myMagic))  continue; // according to MagicNumber only tickets with fitting magicnumber are processed
        found |= (StringFind(OrderComment(), comment)>=0);         // Source Order is not referenced
        if (found) break;
        debug(2, StringConcatenate(comment, " ", OrderComment(), " ", found, " ", StringFind(OrderComment(), comment)));
      }
      if (!found) {
//        rc = OrderSend(mySymbol, limit_type, myLots, myPrice, 3, 0, 0, comment, myMagic, TimeCurrent() + expiry, clrNONE);
        rc = OrderSend(mySymbol, limit_type, myLots, myPrice, 3, 0, 0, comment, myMagic, TimeCurrent() + expiry, clrNONE);
        debug(3, originalTrade);
        debug(2, StringConcatenate("followUpOrder: OrderSend (", mySymbol, ", ", limit_type, ", ", myLots, ", ", myPrice-50, ", 3, 0, 0, ", comment, ", ", myMagic, ", ", TimeCurrent() + expiry, ", CLR_NONE): ", rc));
      }
    }
  }
  return(rc);
}
//+------------------------------------------------------------------+
