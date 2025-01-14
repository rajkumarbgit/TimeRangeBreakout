
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;
CPositionInfo posinfo;
COrderInfo ordinfo;

#include <Indicators\Trend.mqh>
CiIchimoku Ichimoku;
CiMA  MovAvgFast, MovAvgSlow;

enum LST{Fixed=0, RiskPct=1};
enum Hours{_1=1, _2=2, _3=3, _4=4, _5=5, _6=6, _7=7, _8=8, _9=9, _10=10, _11=11, _12=12, _13=13, _14=14, _15=15, _16=16, _17=17, _18=18, _19=19, _20=20, _21=21, _22=22, _23=23, _00=00 };
enum Minutes{_0=0, _5=5, _10=10, _15=15, _20=20, _25=25, _30=30, _35=35, _40=40, _45=45, _50=50, _55=55};
enum TrSides{Onesided=0, Bothside=1};
enum SLType{Yes=0, No=1};
enum TrType{RangePct=0, HighLow=1, Fixedpips=2};
enum TrStyle{With_Break=0, Opposite_to_Break=1};
enum IcTypes{Price_above_Cloud=0, Price_above_Ten=1, Price_above_Kij=2, Price_above_SenA=3, Price_above_SenB=4, Ten_above_Kij=5, Ten_above_Kij_above_cloud=6, Ten_above_Cloud=7, Kij_above_Cloud=8};
enum sep_dropdown{comma=0, semicolon=1};
input group "=== EA Specific Variables ===";
input ulong InpMagic =2345; //EA's identification number
input string TradeComment = "Time Range EA"; //Trade Comment
input TrStyle TradingStyle =0; // Trading with Break or Opposite?
input TrSides TradingSides =1; // Trade One-side or both-sides?
input group "=== Range Parameters ===";
input Hours RangeStartHour=1; //start-Hour for Range
input Minutes RangeStartMin=0; //start-Minute for Range
input Hours RangeEndHour=5; //End-Hour for Range
input Minutes RangeEndMin=0; //End Minutes for Range
input Hours TradeCloseHour=22; //Close Hour for open trades
input Minutes TradeCloseMin=0; //Close Min for open trades
input color rangecolor=clrBeige; //Color of range on screen when within Min/Max Size
input int MinRangeSize=15;//Min Range Size in pips (1 pip =10 points)
input int MaxRangeSize=30;//Max Range Size in pips (1 pip =10 points)
input color rangecolordisabled=clrRed; //Color of range when outside Min/Max Size
input group "=== Trade Management ===";
input LST LotSizeType=0; //Fixed Lotsize or as % of Capital
input double FixedLotSize=1.0; //Fixed Lotsize in case
input double RiskPercent=2; //Risk % of capital on one trade
input ENUM_TIMEFRAMES InpTimeframe=PERIOD_M5; //Timeframe for the EA
input int OrdDistpct=10; //Order Distance Point in % of Range
input int SLPercent=100; //SL % of Range (100% = opposite end of range)
input int TPPercent=180; //TP % of Range (100% = TP equal range size)
input group "=== StopLoss Management ===";
input SLType SLT=1; //Trail Stoploss? (No=Fixed stoploss)
input TrType TrailType=1; //if Yes, What type?
input int TrailFixedpips=30; //Fixed Pips to Trail (if selected)
input int TrailRangePct=90; //What % of Range Size (if selected)
input int BarsN=5; //No of Bars to find High/low (if Selected)
input int HighLowBuffer=2; //Buffer in pips above/below High/Low (if high/low selected)
MqlDateTime starttime, endtime, closetime;
datetime timestart, timeend, timeclose;
int BarsRangeStart, BarstoCount, BuyTotal, SellTotal;
double RangeHigh, RangeLow, RangeSize, Tsl;
input group "=== News Filter ===";
input bool NewsFilterOn=false; //Filter for News?
input sep_dropdown separator=0; // Separator to Separate news keywords
input string KeyNews= "NFP,JOLTS,Nonfarm,Retail,GDP,Confidence,Interest Rate"; //Keywords for News
input string NewsCurrencies= "USD"; //Currencies for News LookUp
input int DaysNewsLookup =100; //No of Days to look up news
input color InpDisabledColor = clrRed; // Chart color when disabled by Upcoming News
ushort sep_code;
string Newstoavoid[];
bool newsprinted=false;
input group "=== Moving Average Filter ===";
input bool MAFilterOn=false; //Buy when Fast MA > Clow MA (Vice cersa for)
input ENUM_TIMEFRAMES MATimeframe=PERIOD_D1; // Time Frame for Mov Average Filter
input int Slow_MA_Period=200; // Slow Moving Average Period
input int Fast_MA_Period=50; // Fast Moving Average Period
input ENUM_MA_METHOD MA_Mode=MODE_EMA; // Moving Average Mode/Method
input ENUM_APPLIED_PRICE MA_AppPrice=PRICE_MEDIAN; // Moving Avg Applied Price
bool MA_BuyOn=true;
bool MA_SellOn=true;
input group "=== Ichimoku Filter ===";
input bool IchimokuFilter=false; // Buy only above cloud and sell only below cl
input IcTypes IchiFilterType =0;  // Buy above which Ichimoku parameter? (opposi
input ENUM_TIMEFRAMES IchiTimeframe =PERIOD_D1; // Ichimoku cloud Timeframe
input int tenkan=9; // period of Tenkansen
input int kijun =26; // period of KijunSen 
input int senkou_b= 52; // period of SenkouSpanB
bool Ichi_BuyOn=true;
bool Ichi_SellOn=true;
  

int OnInit()
  {
   
   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0,CHART_SHOW_GRID, false);
   if(IchimokuFilter==true){
      Ichimoku=new CiIchimoku;
      Ichimoku.Create(_Symbol,IchiTimeframe, tenkan, kijun, senkou_b);
   }

   if (MAFilterOn==true){
      MovAvgSlow = new CiMA;
      MovAvgSlow.Create(_Symbol,MATimeframe,Slow_MA_Period,0,MA_Mode,MA_AppPrice);
      MovAvgFast = new CiMA;
      MovAvgFast.Create(_Symbol,MATimeframe,Fast_MA_Period,0,MA_Mode,MA_AppPrice);
   }
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {

   ObjectsDeleteAll(0,0,OBJ_RECTANGLE);
  }

void OnTick(){

     //if(IsInsideTime()){
      RangeHigh=GetHigh();
      RangeLow=GetLow();
      RangeSize=RangeHigh-RangeLow;
      ShowRange(RangeHigh, RangeLow);
   //}
   if(!IsNewBar()) return;
   
   if(IchimokuFilter) Ichimoku.Refresh(-1);
   if(MAFilterOn){
      MovAvgFast.Refresh(-1);
      MovAvgSlow.Refresh(-1);
   }
   if(IsUpcomingNews()) return;
   CheckforTradeSides();
   CheckforOpenOrdersandPositions();
   if(SLT==0 && (BuyTotal>0 || SellTotal>0)) TrailSL();
   ConvertTimes();
   if(IsInsideTime()){
      RangeHigh=GetHigh();
      RangeLow=GetLow();
      RangeSize=RangeHigh-RangeLow;
      ShowRange(RangeHigh, RangeLow);
   }
   PrepareOrder();
   if(TimeCurrent()>timeclose) CloseandResetAll();

   
}


void ConvertTimes(){
   TimeToStruct(TimeCurrent(), starttime);
   starttime.hour=RangeStartHour; starttime.min = RangeStartMin;
   timestart=StructToTime(starttime);
 
   TimeToStruct(TimeCurrent(), endtime);
   endtime.hour=RangeEndHour; endtime.min=RangeEndMin;
   timeend=StructToTime(endtime);
   
   TimeToStruct(TimeCurrent(), closetime);
   closetime.hour=TradeCloseHour; closetime.min = TradeCloseMin;
   timeclose=StructToTime(closetime);
   
   if(BarsRangeStart==0 && TimeCurrent()>=timestart){
      BarsRangeStart=iBars(_Symbol, InpTimeframe);
      }
}



double GetHigh(){
   double high = 0;
   int highestbar = 0;
   int BarsNow = iBars(_Symbol, InpTimeframe);

   if(TimeCurrent()>timestart && TimeCurrent()<timeend){
      BarstoCount = iBars(_Symbol, InpTimeframe) - BarsRangeStart + 1;
      highestbar= iHighest(_Symbol,InpTimeframe, MODE_HIGH, BarstoCount, 0);
      high=iHigh(_Symbol, InpTimeframe, highestbar);
      if(high!=RangeHigh) return high;
   }
   return RangeHigh;
}



double GetLow(){
   double low = 0;
   int lowestbar = 0;
   //BarstoCount=iBars(_Symbol, InpTimeframe) - BarsRangeStart + 1;
     // lowestbar=iLowest(_Symbol, InpTimeframe, MODE_LOW, BarstoCount, 0);
      //low=iLow(_Symbol, InpTimeframe,lowestbar);
      //if(low!=RangeLow) return low;
   if(TimeCurrent()>timestart && TimeCurrent() <timeend){
      BarstoCount=iBars(_Symbol, InpTimeframe) - BarsRangeStart + 1;
      lowestbar=iLowest(_Symbol, InpTimeframe, MODE_LOW, BarstoCount, 0);
      low=iLow(_Symbol, InpTimeframe,lowestbar);
      if(low!=RangeLow) return low;
   }
   return RangeLow;
}


void ShowRange(double high, double low){
   ObjectCreate(0, "range", OBJ_RECTANGLE, 0, timestart, high, timeend, low);
   if(RangeSize<MaxRangeSize*10*_Point && RangeSize>MinRangeSize*10*_Point){
      ObjectSetInteger (0, "range", OBJPROP_COLOR, rangecolor);
      ObjectSetInteger (0, "range", OBJPROP_FILL, rangecolor);
   }else{
      ObjectSetInteger (0, "range", OBJPROP_COLOR, rangecolordisabled);
      ObjectSetInteger (0, "range", OBJPROP_FILL, rangecolordisabled);
   }
   ObjectCreate(0,"tradingtime", OBJ_RECTANGLE, 0, timeend, high, timeclose, low);
   ObjectSetInteger (0,"tradingtime", OBJPROP_COLOR, rangecolor);
   
   ObjectCreate(0, "endtime", OBJ_VLINE, 0, timeclose, 0);
   ObjectSetInteger (0, "endtime", OBJPROP_COLOR, rangecolor);
}


bool IsInsideTime(){
   MqlDateTime start, now;
   int startmin, nowmin;
   
   TimeToStruct(TimeCurrent(), now);
   nowmin=now.hour*60+ now.min;
   
   TimeToStruct(timestart, start);
   startmin=start.hour*60+ start.min;
   
   if(nowmin >= startmin) return true;
   return false;
}



void PrepareOrder(){
   if(TimeCurrent()>timeend && TimeCurrent() <timeclose){
      double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(RangeSize>MinRangeSize*10*_Point && RangeSize<MaxRangeSize*10*_Point){
            if(ask<RangeHigh-(RangeSize*OrdDistpct/100) && ask>RangeLow+(RangeSize*OrdDistpct/100)){
               if(TradingStyle==0){
                  if (BuyTotal<=0 && MA_BuyOn==true && Ichi_BuyOn==true){
                     //OpenTrade(ORDER_TYPE_BUY_STOP, RangeHigh, RangeHigh-(RangeSize*SLPercent/100));
                     
                     OpenTrade(ORDER_TYPE_BUY_STOP, RangeHigh, RangeHigh-(RangeSize*SLPercent/100));
                  }
                  if(SellTotal<=0 && MA_SellOn==true && Ichi_SellOn==true){
                     //OpenTrade(ORDER_TYPE_SELL_STOP, RangeLow, RangeLow+(RangeSize*SLPercent/100));
                     OpenTrade(ORDER_TYPE_SELL_STOP, RangeLow, RangeLow+(RangeSize*SLPercent/100));
                  }
               }
               if(TradingStyle==1){
                  if(BuyTotal<=0 && MA_BuyOn==true && Ichi_BuyOn==true){
                     //OpenTrade(ORDER_TYPE_BUY_LIMIT, RangeLow, RangeLow- (RangeSize*SLPercent/100));
                     OpenTrade(ORDER_TYPE_BUY_LIMIT, RangeLow, RangeLow- (RangeSize*SLPercent/100));
                  }
                  if(SellTotal<=0 && MA_SellOn==true && Ichi_SellOn==true){
                     //OpenTrade(ORDER_TYPE_SELL_LIMIT, RangeHigh, RangeHigh+ (RangeSize*SLPercent/100));
                     OpenTrade(ORDER_TYPE_SELL_LIMIT, RangeHigh, RangeHigh+ (RangeSize*SLPercent/100));
                  }
               }
            }
        }   
   }
}


void OpenTrade(ENUM_ORDER_TYPE type, double price, double sl){
   
   
   if((MAFilterOn == true && MA_BuyOn==true) &&
      (type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP) && 
      (PricevsMovAvg()=="below" || PricevsMovAvg()=="error")
   ){
      MA_BuyOn=false;
      return;
    }
   if((MAFilterOn == true && MA_SellOn==true) &&
      (type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP) &&
      (PricevsMovAvg()=="above" || PricevsMovAvg()=="error")
   ){
      MA_SellOn=false;
      return;
   }
   
   
   if((IchimokuFilter == true && Ichi_BuyOn==true) &&
      (type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP) &&
      (PricevsIchiCloud() == "below" || PricevsIchiCloud() == "Incloud")
      ){
         MA_BuyOn=false;
         return;
   }
   if((IchimokuFilter == true && Ichi_SellOn==true) &&
      (type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP) &&
      (PricevsIchiCloud()=="above" || PricevsIchiCloud() == "Incloud")
      ){
         MA_SellOn=false;
         return;
   }


   double tp = price + (price-sl) *TPPercent/SLPercent;
   //if(type==ORDER_TYPE_BUY_STOP)
     //{
     // tp=price+100;
     //}
  // if(type==ORDER_TYPE_SELL_STOP)
     //{
    //  tp=price-100;
//}

   //(price-sl>0)? sl = price-sl sl = sl-price;
   double lots=0.01;
   switch(LotSizeType){
      case 0: lots=FixedLotSize; break;
      case 1: lots=calcLots(price-sl);
   }
   
   //if(!trade.OrderOpen(_Symbol, type, lots, 0, price, sl, tp,0,0, TradeComment)){
   if(!trade.OrderOpen(_Symbol, type, lots, 0, price, sl, 0,0,0, TradeComment)){
      printf("Open Failed for %s, %s, price = %f, sl=%f, tp=%f",_Symbol, EnumToString(type), price, sl, tp);
   }
   
}


void CloseandResetAll(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(posinfo.Symbol() == _Symbol && posinfo.Magic()==InpMagic){
         trade.PositionClose(ticket);
      }
   }
   for(int i = OrdersTotal()-1; i>=0; i--){
      ulong ticket = OrderGetTicket(i);
      if(ordinfo.Symbol() == _Symbol && ordinfo.Magic()==InpMagic){
         trade.OrderDelete(ticket);
      }
   }
   BarsRangeStart = 0;
   BuyTotal=0;
   SellTotal=0;
   
   MA_BuyOn = true;
   MA_SellOn = true;
   Ichi_BuyOn = true;
   Ichi_SellOn = true;
   
   newsprinted =false;
   ChartSetInteger(0,CHART_COLOR_BACKGROUND, clrBlack);
}


void TrailSL(){
   for(int i=PositionsTotal()-1; i>=0; i--){
      posinfo.SelectByIndex(i);
      long magic =posinfo.Magic();
      ulong ticket=posinfo.Ticket();
      ENUM_POSITION_TYPE postype = posinfo.PositionType();
      string symbol=posinfo.Symbol();
      
      if(symbol==_Symbol && magic==InpMagic){
         double price =SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl = posinfo.StopLoss();
         double tp=posinfo.TakeProfit();
         double openPrice = posinfo.PriceOpen();
         double high=findHigh();
         double low=findLow();
         

         if(TrailType==0){
            if(postype==POSITION_TYPE_BUY){
               if(price>posinfo.PriceOpen() &&
               //price> posinfo. PriceOpen() + (InpAgrSLTrigger*_Point) &&
               price-RangeSize>sl){
               sl = price - RangeSize*TrailRangePct/100;
               trade.PositionModify(ticket, sl,tp);
            }
         }else
          if(postype==POSITION_TYPE_SELL){
            if(price < posinfo. PriceOpen() &&
            //price posinfo. PriceOpen() (InpAgrSLTrigger*_Point) && 
               price + RangeSize< sl){
               sl = price + RangeSize*TrailRangePct/100;
               trade. PositionModify(ticket, sl, tp);
            }
          }
        }
        
         if(TrailType==1){
            if(postype==POSITION_TYPE_BUY){
               if(price>posinfo.PriceOpen() && low>0){
                  sl = low-HighLowBuffer*10*_Point;
                  if(sl>posinfo.StopLoss())
                  trade.PositionModify(ticket, sl,tp);
               }
         } else
         
         if(postype==POSITION_TYPE_SELL){
            if(price<posinfo.PriceOpen() && high>0){
               sl= high+HighLowBuffer*10*_Point;
               if(sl<posinfo. StopLoss())
               trade.PositionModify(ticket, sl,tp);
            }
          }
         }
        
        
         if(TrailType==2){
            if(postype==POSITION_TYPE_BUY){
               if(price>posinfo.PriceOpen()){
                  sl = price-TrailFixedpips*10*_Point;
                  if(sl>posinfo.StopLoss())
                  trade.PositionModify(ticket, sl,tp);
                }
         }else
         if(postype==POSITION_TYPE_SELL){
            if(price<posinfo.PriceOpen()){
               sl = price + TrailFixedpips*10*_Point;
               if(sl<posinfo. StopLoss())
               trade.PositionModify(ticket, sl, tp);
            }
          }
         }
        
      }
    }
}



void CheckforTradeSides(){
   if(TradingSides==1) return;
   int openPos=0;
   for(int i=PositionsTotal()-1; i>=0; i--){
      posinfo.SelectByIndex(i);
      if(posinfo.Symbol() == _Symbol && posinfo.Magic() ==InpMagic) openPos++;
      
   }

   if(PositionsTotal()>0 && openPos>0){
      for(int i= OrdersTotal()-1; i>=0; i--){
         ordinfo.SelectByIndex(i);
         ulong ticket = ordinfo.Ticket();
         if(ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic){
            trade.OrderDelete(ticket);
         }
       }
   }
}
   

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(previousTime!=currentTime) {
      previousTime=currentTime;
      return true;
   }
   return false;
}


double calcLots(double slPoints){
   double risk=AccountInfoDouble (ACCOUNT_BALANCE) * RiskPercent / 100;
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble (_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble (_Symbol, SYMBOL_VOLUME_STEP);
   double minvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MIN);
   double maxvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MAX);
   double volumelimit=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(slPoints< 0) slPoints = slPoints*-1;
   double moneyPerLotstep=slPoints / ticksize* tickvalue * lotstep;
   double lots=MathFloor(risk/moneyPerLotstep) * lotstep;
   if(volumelimit!=0) lots = MathMin(lots, volumelimit);
   if(maxvolume!=0) lots=MathMin(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   if(minvolume!=0) lots=MathMax(lots, SymbolInfoDouble (_Symbol, SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble(lots, 2);
   return lots;
}


void CheckforOpenOrdersandPositions(){
   for(int i=OrdersTotal()-1; i>=0; i--){
   ordinfo.SelectByIndex(i);
   if(ordinfo.OrderType()==ORDER_TYPE_BUY_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) BuyTotal++;
   if(ordinfo.OrderType()==ORDER_TYPE_SELL_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) SellTotal++;
   if(ordinfo.OrderType()==ORDER_TYPE_BUY_LIMIT && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) BuyTotal++;
   if(ordinfo.OrderType()==ORDER_TYPE_SELL_LIMIT && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) SellTotal++;
   }
   for(int i=PositionsTotal()-1; i>=0; i--){
   posinfo.SelectByIndex(i);
   if(posinfo.PositionType()==POSITION_TYPE_BUY && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) BuyTotal++;
   if(posinfo.PositionType()==POSITION_TYPE_SELL && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) SellTotal++;
   }
}
   

double findHigh(){
   double highestHigh = 0;
   for (int i=0; i<200; i++){
      double high = iHigh(_Symbol, InpTimeframe,i);
      if(i>BarsN && iHighest(_Symbol, InpTimeframe, MODE_HIGH, BarsN*2+1,i-BarsN)==i){
         if(high>highestHigh){
            return high;
         }
      }
      highestHigh=MathMax(high, highestHigh);
   }
   return -1;
}


double findLow(){
   double lowestLow = DBL_MAX;
   for (int i=0; i<200; i++){
      double low=iLow(_Symbol, InpTimeframe,i);
      if(i>BarsN && iLowest(_Symbol, InpTimeframe, MODE_LOW, BarsN*2+1,i-BarsN)==i){
         if(low<lowestLow){
            return low;
         }
      }  
      lowestLow = MathMin(low, lowestLow);
   }
   return -1;
}



bool IsUpcomingNews(){
   if (NewsFilterOn==false) return(false);
   MqlDateTime Today, Newstime;
   string sep; 
   switch(separator){
      case 0: sep = ","; break;
      case 1: sep=";";
   }
   sep_code = StringGetCharacter(sep, 0);
   int k = StringSplit(KeyNews, sep_code, Newstoavoid);
   MqlCalendarValue values[];
   datetime start_time = TimeCurrent(); //iTime (_Symbol, PERIOD_D1,0);
   datetime end_time = start_time + PeriodSeconds(PERIOD_D1)*DaysNewsLookup;
   CalendarValueHistory(values, start_time, end_time, NULL, NULL);
   int x=ArraySize(values);
   for(int i=0; i < ArraySize (values); i++){
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);
      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);
      if(StringFind(NewsCurrencies, country.currency) < 0) continue;
         for (int j=0; j<k; j++){
            string currentevent = Newstoavoid[j];
            string currentnews =event.name;
            if(StringFind(currentnews, currentevent) < 0) continue;
            Comment("Next News: ", country.currency," ", event.name, " -> ", values[i].time);
            TimeToStruct(TimeCurrent(), Today);
            TimeToStruct(values[i].time, Newstime);
            if(Today.day == Newstime.day){
               ChartSetInteger(0, CHART_COLOR_BACKGROUND, InpDisabledColor);
               if(!newsprinted) Print("Trading Disabled today on ",_Symbol," due to upcoming news: ",event.name);
               newsprinted=true;
               return true;
             }
          return false;
            }
         }
       return false;
} 



string PricevsMovAvg(){
   double FastMAnow = MovAvgFast.Main(0);
   double SlowMAnow = MovAvgSlow.Main(0);
   if(FastMAnow>SlowMAnow) return "above";
   if(FastMAnow<SlowMAnow) return "below";
   return "error";
}


string PricevsIchiCloud(){
   double SenA = Ichimoku.SenkouSpanA(0);
   double SenB = Ichimoku.SenkouSpanB(0);
   double Ten = Ichimoku.TenkanSen(0);
   double Kij = Ichimoku.KijunSen(0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(IchiFilterType==0){
      if(ask>SenA && ask>SenB) return "above";
      if(ask<SenA && ask<SenB) return "below";
   }
   
   if(IchiFilterType==1){
      if(ask>Ten) return "above";
      if(ask<Ten) return "below";
   }
   if(IchiFilterType==2){
      if(ask>Kij) return "above";
      if(ask<Kij) return "below";
   }
   if(IchiFilterType==3){
      if(ask>SenA) return "above";
      if(ask<SenA) return "below";
   }
   if(IchiFilterType==4){
      if(ask>SenB) return "above";
      if(ask<SenB) return "below";
   }
   if(IchiFilterType==5){
      if(Ten>Kij) return "above";
      if(Ten>Kij) return "below";
   }
   if (IchiFilterType==6){
      if(Ten>Kij && Kij>SenA && Kij>SenB) return "above";
      if(Ten<Kij && Kij<SenA && Kij<SenB) return "below";
   }

   if(IchiFilterType==7){
      if(Ten>SenA && Ten>SenB) return "above";
      if(Ten<SenA && Ten<SenB) return "below";
   }
   if(IchiFilterType==8){
      if(Kij>SenA && Kij>SenB) return "above";
      if(Kij<SenA && Kij<SenB) return "below";
   }
   // enum IcTypes {Cloud-8, Tenkansen-1, Kijunsen-2, SenA=3, SenB-4, Ten_above_Kij-5, Ten_above_Kij_above_Cloud-6, Ten_
return "Incloud";
}