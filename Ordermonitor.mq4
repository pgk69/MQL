//+------------------------------------------------------------------+
//|                                                 Ordermonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

//--- input parameters
//- Wenn angegeben werden nur Trades mit dieser Magic Number ueberwacht
extern int MagicNumber = 0;

//--- Global variables


// Include the OrderManager.
#include <OrderManager.mqh>

// Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  OrderManager_Init();
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
  manageOrders(MagicNumber);
}
