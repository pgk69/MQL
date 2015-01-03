//+------------------------------------------------------------------+
//|                                                 Ordermonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

//--- input parameters
//- Wenn angegeben werden nur Trades mit dieser Magic Number ueberwacht
extern int MagicNumber          = 0;

//--- Global variables


// Include the OrderManager.
#include <OrderManager.mqh>

// Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
  OrderManager_Init();
  return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
  return(0);
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
  manageOrders(MagicNumber);
  return(0);
}