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

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
void ExitStrategies_Init() export {
  debug(1, StringConcatenate("ExitStrategies Version: ", VERSION));
}


// when I buy  long  I get the ask price
// when I sell long  I get the bid price
// when I buy  short I get the bid price
// when I sell short I get the ask price
//+------------------------------------------------------------------+
//| determine initial TP                                             |
//+------------------------------------------------------------------+
double initial_TP(double myTP, double TPPips, bool& initialTP) export {
  MqlTick tick;
  double newTP = myTP;

  initialTP = false;
  if (myTP == 0) {
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        newTP = NormRound(tick.bid + TPPips);
      }
      if (OrderType() == OP_SELL) {
        newTP = NormRound(tick.ask - TPPips);
      }
    
      if (newTP != myTP) {
        debug(2, StringConcatenate("initial TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newTP));
        initialTP = true;
      }
    }
  }

  return(newTP);
}


//+------------------------------------------------------------------+
//| determine trailing TP                                            |
//+------------------------------------------------------------------+
double trailing_TP(double Correction, double myTP, double TPPips, double TPTrailPips, bool& initialTP, bool& resetTP) export {
  MqlTick tick;
  double newTPTrail;
  double newTP = initial_TP(myTP, TPPips, initialTP);

  resetTP = false;
  if (myTP != 0) {
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        newTPTrail = NormRound(tick.bid + Correction*TPTrailPips);
        newTP      = fmax(myTP, newTPTrail);                           // TP will never be decreased
      }
      if (OrderType() == OP_SELL) {
        newTPTrail = NormRound(tick.ask - Correction*TPTrailPips);
        newTP      = fmin(myTP, newTPTrail);                           // TP will never be increased
      }
    
      if (newTP != myTP) {
        debug(2, StringConcatenate("new trailing TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", myTP, " new: ", newTP));
        resetTP = true;
      }
    }
  }

  return(newTP);
}


//+------------------------------------------------------------------+
//| determine initial SL                                             |
//+------------------------------------------------------------------+
double initial_SL(double mySL, double SLPips, bool& initialSL) export {
  MqlTick tick;
  double newSL = mySL;

  initialSL = false;
  if (mySL == 0) {
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        newSL = NormRound(tick.bid - SLPips);
      }
      if (OrderType() == OP_SELL) {
        newSL = NormRound(tick.ask + SLPips);
      }
      if (newSL != mySL) {
        debug(2, StringConcatenate("initial StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newSL));
        initialSL = true;
      }
    }
  }

  return(newSL);
}


//+------------------------------------------------------------------+
//| determine trailing SL                                            |
//+------------------------------------------------------------------+
double trailing_SL(double Correction, double mySL, double SLPips, double SLTrailPips, bool& initialSL, bool& resetSL, bool resetTP) export {
  MqlTick tick;
  double newSL = initial_SL(mySL, SLPips, initialSL);

  resetSL = false;
  if (mySL != 0) {
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        if (resetTP) {  // Increase Trailing SL if TP was increased; SL will never be decreased
          newSL = fmax(mySL, NormRound(tick.bid - SLTrailPips));
        }
      }
      if (OrderType() == OP_SELL) {
        if (resetTP) {  // Decrease Trailing SL if TP was decreased; SL will never be increased
          newSL = fmin(mySL, NormRound(tick.ask + SLTrailPips));
        }
      }
      if (newSL != mySL) {
        debug(2, StringConcatenate("new trailing StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", mySL, " new: ", newSL));
        resetSL = true;
      }
    }
  }

  return(newSL);
}


//+------------------------------------------------------------------+
//| determine N-Bar SL                                               |
//+------------------------------------------------------------------+
double N_Bar_SL(double mySL, double SLPips, bool& initialSL, bool& resetSL, int timeframe, int barCount, double timeframeFaktor) export {
  MqlTick tick;
  double newSL = initial_SL(mySL, SLPips, initialSL);
  
  if (timeframe < 0) {
    // no timeframe is given, so we decide outselfs
    // based on how long the order is activ
    int barTime = round((TimeCurrent()-OrderOpenTime())/barCount);
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

  resetSL = false;
  if (mySL != 0) {
    // only if it's not an initial
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        double Min_N_Bar = 1000000000;
        int i = barCount;
        while (i>0) Min_N_Bar = fmin(Min_N_Bar, iLow(OrderSymbol(), timeframe, i--));
        newSL = fmax(mySL, Min_N_Bar);
        // Print("fmax(mySL=", mySL, ", Min_N_Bar=", Min_N_Bar, ")=", newSL);
      }
      if (OrderType() == OP_SELL) {
        double Max_N_Bar = -1000000000;
        int i = barCount;
        while (i>0) Max_N_Bar = fmax(Max_N_Bar, iHigh(OrderSymbol(), timeframe, i--));
        newSL = fmin(mySL, Max_N_Bar);
        // Print("fmin(mySL=", mySL, ", Max_N_Bar=", Max_N_Bar, ")=", newSL);
      }
      if (newSL != mySL) {
        debug(2, StringConcatenate("new N-Bar StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", mySL, " new: ", newSL));
        resetSL = true;
      }
    }
  }

  return(newSL);
}
//+------------------------------------------------------------------+
