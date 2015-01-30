//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#define VERSION     "1.0"
//
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
//
//+------------------------------------------------------------------+
//| EX4 includes                                                     |
//+------------------------------------------------------------------+
#include <stderror.mqh>
#include <stdlib.mqh>
//
//+------------------------------------------------------------------+
#ifndef __ExitStrategies_H__
#define __ExitStrategies_H__

#import "ExitStrategies.ex4"
  void ExitStrategies_Init;
  double initial_TP();
  double initial_SL();
  double trailing_TP();
  double trailing_SL();
  double N_Bar_SL();
#import

#endif