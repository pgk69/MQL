//+------------------------------------------------------------------+
//|                                                 RandomTrader.mq4 |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict

//--- input parameters
//- MagicNumber:    0: Every trade will be monitored
//               <> 0: Only trades with MagicNumber will be monitored
extern int Debug             = 3;      // Debug Level
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert
extern bool initialize       = true;   // New Initialization?

input int MagicNumber        = 0;

input int SLPips             = 50;     // Stoploss Pips
input int TPPips             = 150;    // TakeProfit Pips

input int MaxWait            = 60;     // Max. WaitTime before next Trade
input bool dual              = true;   // Trade short and long togather

input double LotSize         = 0.1;    // Lot Size

input bool AUDUSD            = false;  // Trade AUDUSD
input bool EURAUD            = false;  // Trade EURAUD
input bool EURGBP            = false;  // Trade EURGBP
input bool EURJPY            = false;  // Trade EURJPY
input bool EURUSD            = false;  // Trade EURUSD
input bool GBPCAD            = false;  // Trade GBPCAD
input bool GBPCHF            = false;  // Trade GBPCHF
input bool GBPUSD            = false;  // Trade GBPUSD
input bool USDCAD            = false;  // Trade USDCAD
input bool USDCHF            = false;  // Trade USDCHF

//--- Type Definitions
struct trade_type {string Symbol;
                   double SL;
                   double TP;
                   int    ShortID;
                   int    LongID;
                   int    nextTrade;
                   int    PIPCorrection;
                   bool   valid;
                   bool   ShortRunning;
                   bool   LongRunning;};

//--- Global variables
trade_type trade[10];

//--- Includes
#include <stdlib.mqh>
#include <ToolBox.mqh>

//--- Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  debugLevel(Debug);
  RandomTrader_Init();
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| random trader initialization function                            |
//+------------------------------------------------------------------+
void RandomTrader_Init() {
  if (initialize) {
    ToolBox_Init();
    debug(1, "RandomTrader_Init: RandomTrader Version: " + VERSION);
    MathSrand(GetTickCount());
    
    // AUDUSD
    trade[0].Symbol        = "AUDUSD";
    trade[0].valid         = AUDUSD;
    trade[0].PIPCorrection = 10;

    // EURAUD
    trade[1].Symbol        = "EURAUD";
    trade[1].valid         = EURAUD;
    trade[1].PIPCorrection = 10;
    
    // EURGBP
    trade[2].Symbol        = "EURGBP";
    trade[2].valid         = EURGBP;
    trade[2].PIPCorrection = 10;
    
    // EURJPY
    trade[3].Symbol        = "EURJPY";
    trade[3].valid         = EURJPY;
    trade[3].PIPCorrection = 10;
    
    // EURUSD
    trade[4].Symbol        = "EURUSD";
    trade[4].valid         = EURUSD;
    trade[4].PIPCorrection = 10;
    
    // GBPCAD
    trade[5].Symbol        = "GBPCAD";
    trade[5].valid         = GBPCAD;
    trade[5].PIPCorrection = 10;
    
    // GBPCHF
    trade[6].Symbol        = "GBPCHF";
    trade[6].valid         = GBPCHF;
    trade[6].PIPCorrection = 10;
    
    // GBPUSD
    trade[7].Symbol        = "GBPUSD";
    trade[7].valid         = GBPUSD;
    trade[7].PIPCorrection = 10;
    
    // USDCAD
    trade[8].Symbol        = "USDCAD";
    trade[8].valid         = USDCAD;
    trade[8].PIPCorrection = 10;
    
    // USDCHF
    trade[9].Symbol        = "USDCHF";
    trade[9].valid         = USDCHF;
    trade[9].PIPCorrection = 10;

    for (int idx=0; idx<10; idx++) {
      pipCorrection(trade[idx].PIPCorrection);
      trade[idx].SL            = calcPips(0, SLPips, trade[idx].Symbol);
      trade[idx].TP            = calcPips(0, TPPips, trade[idx].Symbol);
      trade[idx].nextTrade     = -1;
      trade[idx].ShortID       = (int)GlobalVariableGet("RandomTrader_ShortID" + i2s(idx));
      trade[idx].LongID        = (int)GlobalVariableGet("RandomTrader_LongID" + i2s(idx));
      trade[idx].ShortRunning  = OrderSelect(trade[idx].ShortID, SELECT_BY_TICKET) && (OrderCloseTime() == 0);
      trade[idx].LongRunning   = OrderSelect(trade[idx].LongID, SELECT_BY_TICKET)  && (OrderCloseTime() == 0);
      if (trade[idx].valid) {
        debug(1, "RandomTrader: " + trade[idx].Symbol + "  SL: " + d2s(trade[idx].SL) + "  TP: " + d2s(trade[idx].TP) + "  ShortID: " + i2s(trade[idx].ShortID) + " (" + i2s(trade[idx].LongRunning) + ")  LongID: " + i2s(trade[idx].LongID) + " (" + i2s(trade[idx].LongRunning) + ")");
      }
    }

    initialize = false;
  }
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
  int idx = ArraySize(trade);

  // for each Symbol to be processed
  while (idx > 0) {
    idx--;
    if (trade[idx].valid) {
      // check whether there is a trade
      trade[idx].ShortRunning  = OrderSelect(trade[idx].ShortID, SELECT_BY_TICKET) && (OrderCloseTime() == 0);
      trade[idx].LongRunning   = OrderSelect(trade[idx].LongID, SELECT_BY_TICKET)  && (OrderCloseTime() == 0);

      if (trade[idx].LongRunning || trade[idx].ShortRunning) {
        trade[idx].nextTrade = (int)TimeCurrent() + (rand() % MaxWait);
        debug(3, "RandomTrade: " + trade[idx].Symbol + ": Trade running (ShortID: " + i2s(trade[idx].ShortID) + ", LongID: " + i2s(trade[idx].LongID) + "). New Reset set to: " + d2s(trade[idx].nextTrade) + " (current time: " + d2s(TimeCurrent()) + ")");
      } else {
        // check whether random wait time is over 
        if (trade[idx].nextTrade < (int)TimeCurrent()) {
          // open e new Trade
          int SELLBUY = rand() % 2;
          if (SELLBUY || dual) {
            // SELL
            double price = SymbolInfoDouble(trade[idx].Symbol, SYMBOL_BID);
            trade[idx].ShortID = OrderSend(trade[idx].Symbol, OP_SELL, LotSize, price, 3, price + trade[idx].SL, price - trade[idx].TP, "RandomTrading", MagicNumber, 0, clrNONE);
            GlobalVariableSet("RandomTrader_ShortID"+i2s(idx), trade[idx].ShortID); 
            debug(1, "RandomTrade: OrderSend (" + trade[idx].Symbol + ", OP_SELL, " + d2s(LotSize) + ", " + d2s(price) + ", 3, " + d2s(price+trade[idx].SL) + ", " + d2s(price-trade[idx].TP)+ ", RandomTrading, " + i2s(MagicNumber) + ", 0, CLR_NONE)");
          }
          if (!SELLBUY || dual) {
            // BUY
            double price = SymbolInfoDouble(trade[idx].Symbol, SYMBOL_ASK);
            trade[idx].LongID = OrderSend(trade[idx].Symbol, OP_BUY, LotSize, price, 3, price - trade[idx].SL, price + trade[idx].TP, "RandomTrading", MagicNumber, 0, clrNONE);
            GlobalVariableSet("RandomTrader_LongID"+i2s(idx), trade[idx].LongID); 
            debug(1, "RandomTrade: OrderSend (" + trade[idx].Symbol + ", OP_BUY, " + d2s(LotSize) + ", " + d2s(price) + ", 3, " + d2s(price-trade[idx].SL) + ", " + d2s(price+trade[idx].TP)+ ", RandomTrading, " + i2s(MagicNumber) + ", 0, CLR_NONE)");
          }
        } else {
          debug(2, "RandomTrade: " + trade[idx].Symbol + ": NextTrade not before: " + d2s(trade[idx].nextTrade) + " (current time: " + d2s(TimeCurrent()) + ")");
        }
      }
    }
  }
}