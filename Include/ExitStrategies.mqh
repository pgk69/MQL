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
  int ExitStrategieStatus(string strategie, bool On);
  void checkTrade(int ticket, double TPPips, double SLPips);
  bool SL_is_active(int ticket);
  double TakeProfit(int ticket, string &message, double TP, double TPPips, double TPTrailPips, double Correction);
  double StopLoss(int ticket, string &message, double SL, double TPPips, double SLPips, double SLTrailPips, double Correction, int timeframe, int barCount, double timeframeFaktor, double SLStepsPips, double SLStepsDist);
  string initial_TP(double &TP, double TPPips);
  string initial_SL(double &SL, double SLPips);
  string trailing_TP(double &TP, double TPPips, double TPTrailPips, double Correction);
  string trailing_SL(double &SL, double SLPips, double SLTrailPips, double Correction);
  string N_Bar_SL(double &SL, double SLPips, int timeframe, int barCount, double timeframeFaktor);
  string Steps_SL(double &SL, double SLStepsPips, double SLStepsDist);
  string DSteps_SL(double &SL, double &steps[]);
  int followUpOrder(int ticketID, int expiry);
#import

#endif