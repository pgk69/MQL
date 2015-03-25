//+------------------------------------------------------------------+
//|                                                  ExitMonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

//--- type definitons
enum Abs_Proz 
  {
   Pips=0,     // Pips
   Percent=1,  // Percent
  };

//--- input parameters
//- MagicNumber:    0: Every trade will be monitored
//               <> 0: Only trades with MagicNumber will be monitored
extern int Debug             = 2;  // Debug Level
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

input int MagicNumber        = 0;

//- onlyCurrentSymbol: true:  Only the current Symbol will be monitored
//                     false: every Symbol will be monitored
input bool onlyCurrentSymbol = true;

input Abs_Proz Percent       = Percent;  // Values given in Pips or Percent

// determine initial TP  30 Pipa = 0.3 Percent
// Pips: 30
// Percent: 0.3
input double TP_Val          = 0.3;   // Initial TP Value

// determine trailing TP
input double TP_Trail_Val    = 0.05;  // Trailing TP Value

// determine initial SL
input double SL_Val          = 0.3;   // Initial SL Value

// determine trailing SL
input bool SL_Trail_activ    = true;  // Activate Trailing SL?
input double SL_Trail_Val    = 0.05;  // Trailing SL Value

// determine N_Bar SL
input bool SL_N_Bar_activ    = false; // Activate N-Bar SL?
input int BarCount           = 3;     // N-Bar SL: Number of Bars
input int TimeFrame          = -1;    // N-Bar SL: TimeFrame (Autodetect: -1)
input double TimeFrameFaktor = 1.5;   // N-Bar SL: Adatption Timefaktor

// determine Steps SL
input bool SL_Steps_activ    = false; // Activate Steps SL?
input double SL_Steps_Size   = 0.15;  // Steps SL: Size of one Step
input double SL_Steps_Val    = 0.05;  // Steps SL: Triggerdistance above one Stepborder

input bool FollowUp_activ    = false; // Activate FollowUp Trade?
extern int FollowUpExpiry    = 1800;  // FollowUp Order Expiry Time

input int MaxRetry           = 10;   // OrderSend/OrderModify max. Retry
input int PipCorrection      = 1;    // Correction faktor for calculation Pips from Price
                                     // ActivTrades DAX: 10

//--- Global variables
//double tpValue[101];
//double slValue[101];

//--- Includes
//#include <stderror.mqh>
#include <stdlib.mqh>
#include <ToolBox.mqh>
#include <ExitStrategies.mqh>

//--- Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  debugLevel(Debug);
  ToolBox_Init();
  ExitStrategies_Init();
  pipCorrection(PipCorrection);
  if (FollowUpExpiry < 600) debug(1, "ExitMonitor: FollowUpExpiry must be >= 600");
  FollowUpExpiry = fmax(600, FollowUpExpiry);
  ExitStrategieStatus("Trailing",      SL_Trail_activ);
  ExitStrategieStatus("N-Bar",         SL_N_Bar_activ);
  ExitStrategieStatus("Steps",         SL_Steps_activ);
  ExitStrategieStatus("FollowUpOrder", FollowUp_activ);
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick() {
  int rcint, Retry;
  bool rc;

  // Bearbeitung aller offenen Trades
  debug(4, "ExitMonitor: Read Orderbook (Total of all Symbols: " + i2s(OrdersTotal()) + ")");
  for (int i=0; i<OrdersTotal(); i++) {
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue; // Only valid Tickets are processed
    if ((OrderType() > OP_SELL))                             continue; // Only OP_BUY or OP_SELL Tickets are processed
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))    continue; // according to onlyCurrentSymbol only tickets trading the current symbol are processed
    if (MagicNumber && (OrderMagicNumber() != MagicNumber))  continue; // according to MagicNumber only tickets with fitting magicnumber are processed
    
    // Save my Values
    int    myTicket          = OrderTicket();
    int    myOrderType       = OrderType();
    string myOrderSymbol     = OrderSymbol();
    double myOrderOpenPrice  = OrderOpenPrice();
    double myOrderTakeProfit = OrderTakeProfit();
    double myOrderStopLoss   = OrderStopLoss();
    double myOrderLots       = OrderLots();
    
    // Possibly determine an correctionfactor
    double Correction  = indFaktor();
    // Calculate real Pips depending on the value given in precent or absolut
    double TPPips      = calcPips(Percent, TP_Val);
    double SLPips      = calcPips(Percent, SL_Val);
    double TPTrailPips = calcPips(Percent, TP_Trail_Val);
    double SLTrailPips = calcPips(Percent, SL_Trail_Val);
    double SLStepsPips = calcPips(Percent, SL_Steps_Size);
    double SLStepsDist = calcPips(Percent, SL_Steps_Val);
  
    bool newTP = 0;
    bool newSL = 0;
    double TP = 0;
    double SL = 0;
    string TPMessage = "";
    string SLMessage = "";

    // Caluculate new TP Value
    TP = TakeProfit(myTicket, TPMessage, myOrderTakeProfit, TPPips, TPTrailPips, Correction);
    newTP = (NormalizeDouble(TP-myOrderTakeProfit, 5) != 0);
  
    // Calculate new SL Value
    SL = StopLoss(myTicket, SLMessage, myOrderStopLoss, TPPips, SLPips, SLTrailPips, Correction, TimeFrame, BarCount, TimeFrameFaktor, SLStepsPips, SLStepsDist);
    newSL = (NormalizeDouble(SL-myOrderStopLoss, 5) != 0);   

    if (newSL || newTP) {
      if (debugLevel() >= 1) {
        string message = "";
        if (newTP) message = message + " new " + TPMessage + "TP:" + d2s(myOrderTakeProfit) + "->" + d2s(TP) + " ";
        if (newSL) message = message + " new " + SLMessage + "SL:" + d2s(myOrderStopLoss) + "->" + d2s(SL);
        if (NormalizeDouble(Correction-1, 5) != 0) message = message + " Corrections determined as: " + d2s(Correction);
        debug(1, "ExitMonitor: " + message);
        if (debugLevel() >= 2) {
          if (NormalizeDouble(TP_Val       -TPPips, 5)      != 0) debug(2, "ExitMonitor: TP Pips changed from "                  + d2s(TP_Val)        + " to " + d2s(TPPips));
          if (NormalizeDouble(TP_Trail_Val -TPTrailPips, 5) != 0) debug(2, "ExitMonitor: TP trailing Pips changed from "         + d2s(TP_Trail_Val)  + " to " + d2s(TPTrailPips));
          if (NormalizeDouble(SL_Val       -SLPips, 5)      != 0) debug(2, "ExitMonitor: SL Pips changed from "                  + d2s(SL_Val)        + " to " + d2s(SLPips));
          if (NormalizeDouble(SL_Trail_Val -SLTrailPips, 5) != 0) debug(2, "ExitMonitor: SL trailing Pips changed from "         + d2s(SL_Trail_Val)  + " to " + d2s(SLTrailPips));
          if (NormalizeDouble(SL_Steps_Size-SLStepsPips, 5) != 0) debug(2, "ExitMonitor: SL Steps Size (Pips) changed from "     + d2s(SL_Steps_Size) + " to " + d2s(SLStepsPips));
          if (NormalizeDouble(SL_Steps_Val -SLStepsDist, 5) != 0) debug(2, "ExitMonitor: SL Steps Distance (Pips) changed from " + d2s(SL_Steps_Val)  + " to " + d2s(SLStepsDist));
        }
      }
      Retry  = 0;
      rc     = false;
      rcint  = 0;
      string executedOrder;
      while (!rc && (Retry<MaxRetry)) {
        RefreshRates();
        MqlTick tick;
        SymbolInfoTick(myOrderSymbol, tick);
        if (OrderType() == OP_BUY) {
          if (NormalizeDouble(SL-tick.bid, 5) > 0.00001) {
            rc = OrderClose(myTicket, myOrderLots, tick.bid, 3, clrNONE);
            executedOrder = "OrderClose (" + i2s(myTicket) + ") rc: " + i2s(rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = "OrderModify (" + i2s(myTicket) + ", 0, " + d2s(SL) + ", " + d2s(TP) + ", 0, CLR_NONE) TP/SL set: " + i2s(rc);
            if (SL_is_active(myTicket)) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        if (OrderType() == OP_SELL) {
          if (NormalizeDouble(tick.bid-SL, 5) > 0.00001) {
            rc = OrderClose(myTicket, myOrderLots, tick.ask, 3, clrNONE);
            executedOrder = "OrderClose (" + i2s(myTicket) + ") rc: " + i2s(rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = "OrderModify (" + i2s(myTicket) + ", 0, " + d2s(SL) + ", " + d2s(TP) + ", 0, CLR_NONE) TP/SL set: " + i2s(rc);
            if (SL_is_active(myTicket)) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        Retry++;
      }
      if (!rc) {
        rcint = GetLastError();
        debug(1, "ExitMonitor: " + executedOrder + " " + i2s(rc) + " " + i2s(rcint) + " " + i2s(Retry) + ": " + ErrorDescription(rcint));
      } else {
        debug(3, "ExitMonitor: " + executedOrder + "  Retry: " + i2s(Retry));
      }
    }
  }
}