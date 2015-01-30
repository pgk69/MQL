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
//
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
//
//+------------------------------------------------------------------+
//| EX4 includes                                                     |
//+------------------------------------------------------------------+
//#include <stderror.mqh>
//#include <stdlib.mqh>
//
//+------------------------------------------------------------------+
#ifndef __ExitStrategies_H__
#define __ExitStrategies_H__

#import "ExitStrategies.ex4"
  void ExitStrategies_Init();
  double initial_TP(double myTP, double TPPips, bool& initialTP);
  double initial_SL(double mySL, double SLPips, bool& initialSL);
  double trailing_TP(double Correction, double myTP, double TPPips, double TPTrailPips, bool& initialTP, bool& resetTP);
  double trailing_SL(double Correction, double mySL, double SLPips, double SLTrailPips, bool& initialSL, bool& resetSL, bool resetTP);
  double N_Bar_SL(double mySL, double SLPips, bool& initialSL, bool& resetSL, int timeframe, int barCount);
#import

#endif