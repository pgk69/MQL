//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property strict

#define VERSION     "1.0"

#include <stderror.mqh>
#include <stdlib.mqh>
#include <ToolBox.mqh>


//--- input parameters
// common

extern int DebugLevel;

//--- Global variables
bool newTPset;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
void ExitStrategies_Init() export {
  Print("ExitStrategies Version: ", VERSION);
}


// when I buy  long  I get the ask price
// when I sell long  I get the bid price
// when I buy  short I get the bid price
// when I sell short I get the ask price
//+------------------------------------------------------------------+
//| determine initial TP                                             |
//+------------------------------------------------------------------+
double initial_TP(double myTP, double TPPips, bool& initialTP) {
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
        if (DebugLevel > 0) {
          Print(OrderSymbol()," initial TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newTP);
        }
        initialTP = true;
      }
    }
  }

  return(newTP);
}


//+------------------------------------------------------------------+
//| determine trailing TP                                            |
//+------------------------------------------------------------------+
double trailing_TP(double Correction, double myTP, double TPPips, double TPTrailPips, bool& initialTP, bool& resetTP) {
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
        if (DebugLevel > 0) {
          Print(OrderSymbol()," new TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", myTP, " new: ", newTP);
        }
        resetTP = true;
      }
    }
  }

  return(newTP);
}


//+------------------------------------------------------------------+
//| determine initial SL                                             |
//+------------------------------------------------------------------+
double initial_SL(double mySL, double SLPips, bool& initialSL) {
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
        if (DebugLevel > 0) {
          Print(OrderSymbol()," initial StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newSL);
        }
        initialSL = true;
      }
    }
  }

  return(newSL);
}


//+------------------------------------------------------------------+
//| determine trailing SL                                            |
//+------------------------------------------------------------------+
double trailing_SL(double Correction, double mySL, double SLPips, double SLTrailPips, bool& initialSL, bool& resetSL, bool resetTP) {
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
        if (DebugLevel > 0) {
          Print(OrderSymbol()," new StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", mySL, " new: ", newSL);
        }
        resetSL = true;
      }
    }
  }

  return(newSL);
}


//+------------------------------------------------------------------+
//| determine N-Bar SL                                               |
//+------------------------------------------------------------------+
double N_Bar_SL(double mySL, double SLPips, bool& initialSL, bool& resetSL, int timeframe, int N) {
  MqlTick tick;
  double newSL = initial_SL(mySL, SLPips, initialSL);
  
  if (timeframe < 0) {
    // no timeframe is given, so we decide outselfs
  }

  resetSL = false;
  if (mySL != 0) {
    // only if it's not an initial
    if (SymbolInfoTick(OrderSymbol(), tick)) {
      if (OrderType() == OP_BUY) {
        double Min_N_Bar = 1000000000;
        int i = N;
        while (i>0) Min_N_Bar = fmin(Min_N_Bar, iLow(OrderSymbol(), timeframe, i--));
        newSL = fmax(mySL, Min_N_Bar);
      }
      if (OrderType() == OP_SELL) {
        double Max_N_Bar = -1000000000;
        int i = N;
        while (i>0) Max_N_Bar = fmax(Max_N_Bar, iHigh(OrderSymbol(), timeframe, i--));
        newSL = fmin(mySL, Max_N_Bar);
      }
      if (newSL != mySL) {
        if (DebugLevel > 0) {
          Print(OrderSymbol()," new StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Buyprice: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " old: ", mySL, " new: ", newSL);
        }
        resetSL = true;
      }
    }
  }

  return(newSL);
}
//+------------------------------------------------------------------+
