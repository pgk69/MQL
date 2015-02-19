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
  int ExitStrategies(string strategie, bool On);
  double TP(double TP, double TPPips, double TPTrailPips, double Correction, bool& initialTP, bool& resetTP);
  double SL(double SL, double TPPips, double SLPips, double SLTrailPips, double Correction, bool& initialSL, bool& resetSL, bool resetTP, int timeframe, int barCount, double timeframeFaktor, int ticketID, int expirys);
  string initial_TP(double& TP, double TPPips, bool& initialTP);
  string initial_SL(double& SL, double SLPips, bool& initialSL);
  string trailing_TP(double& TP, double TPPips, double TPTrailPips, double Correction, bool& initialTP, bool& resetTP);
  string trailing_SL(double& SL, double SLPips, double SLTrailPips, double Correction, bool& initialSL, bool& resetSL, bool resetTP);
  string N_Bar_SL(double& SL, double SLPips, bool& initialSL, bool& resetSL, bool resetTP, int timeframe, int barCount, double timeframeFaktor);
  int followUpOrder(int ticketID, int expiry);
#import

#endif