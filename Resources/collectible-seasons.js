'use strict';
// Original application pixel drawings. No downloaded artwork or runtime requests.
(()=>{
 const colors={K:'#443b46',W:'#fff5dc',S:'#d9e6e7',I:'#91b8c3',B:'#538caa',D:'#355774',R:'#b64e4a',P:'#e59a9d',O:'#d98240',Y:'#edbd64',G:'#6b9861',L:'#a8ba72',T:'#866246',N:'#b58c61',V:'#79628a',H:'#b5a0bf'};
 const drawings={
  'winter-0':[
   '................','.......YY.......','.......YY.......','......YYYY......','..YYYYYYYYYYYY..','...YYYYYYYYYY...','....YYWWYYYY....','.....YWWYYY.....','....YYYYYYYY....','...YYYY..YYYY...','...YYY....YYY...','...YY......YY...','................','................','................','................'],
  'winter-1':[
   '................','.....KKKK.......','....KRRRRK......','....KRPRRK......','....KRPRRK..KK..','....KRRRRK.KRRK.','....KRRRRKKRRRK.','....KRRRRRRRRK..','....KRRRRRRRK...','....KRRRRRRK....','....KRRRRRRK....','....KWWWWWWK....','....KSSSSSSK....','.....KKKKKK.....','................','................'],
  'winter-2':[
   '..........KK....','..........RK....','.......WW.RK....','......WWWWRK....','.....WWWWWWK....','....WWWWWWWW....','...WSSSSSSSSW...','..WTTTTTTTTTTW..','...TWWTTTWWTT...','...TWYTTTYWTT...','...TTTTTTTTTT...','...TTTTKKTTTT...','...TTTTKNTTTT...','...TTTTKNTTTT...','..WWWWWWWWWWWW..','................'],
  'spring-0':[
   '................','................','....LL....LL....','...LGGL..LGGL...','...LGGGL.LGGL...','....LGGL.LGL....','.....LGLLGL.....','.......GG.......','.......GG.......','.......GG.......','....NNNGGNNN....','...NTTTTTTTTN...','....NNNNNNNN....','................','................','................'],
  'spring-1':[
   '................','.....R...R......','.....RR.RR......','.....RPRPR......','.....RPPPR......','......RRR.......','.......G........','....LG.G........','.....LGG.GL.....','......GGGL......','...TTTTTTTTT....','...TNNNNNNNT....','....TOOOOOT.....','....TOOOOOT.....','.....TTTTT......','................'],
  'spring-2':[
   '................','.......RR.......','......RNNR......','.....RNNNNR.....','....RNNNNNNR....','...RRRRRRRRRR...','....TYYYYYYT....','....TYKKKKYT....','....TYKDDKYT....','....TYKKKKYT....','....TYYYYYYT....','....TTTTTTTT....','.......TT.......','.......TT.......','......TTTT......','................'],
  'summer-0':[
   '................','................','........WWWW....','......WWBBBBW...','.....WBBBBBBW...','....WBBBWWWW....','....WBBBW.......','...WBBBBW.......','..WBBBBBBW......','.WWBBBBBBBWWW...','WBBBBBBBBBBBBWW.','BBBBBBBBBBBBBBBB','DDDDDDDDDDDDDDDD','................','................','................'],
  'summer-1':[
   '................','......OOOO......','....OOPPPPOO....','...OPPWPWPPPO...','..OPWPWPWPWPPO..','..OPWPWPWPWPPO..','..OPPWPWPWPPPO..','...OPWPWPWPPO...','...OPPWPWPWPO...','....OPWPWPPO....','.....OPWPPO.....','.....OOPPOO.....','......OOOO......','................','................','................'],
  'summer-2':[
   '................','.......TT.......','......RRRR......','....RRWWRRWW....','...RRWWWRRWWW...','..RRWWWWRRWWWW..','.RRWWWWWRRWWWWR.','.RRWWRRRRRRWWRR.','.......TT.......','.......TT.......','.......TT.......','.......TT.......','.......TT.......','...YYYYTTYYYY...','..YYYYYYYYYYYY..','................'],
  'autumn-0':[
   '................','.......R........','......RRR.......','...R..ROR..R....','...RR.ROR.RR....','....RRRORRR.....','.RRRRROOORRRRR..','..ROOOOOOOOOR...','...ROOOYOOOR....','..RRROOYORRRR...','.....ROYOR......','.......T........','.......T........','........T.......','................','................'],
  'autumn-1':[
   '................','........TT......','.......TT.......','.....TTTTTT.....','....TNTNTNTT....','...TNTNTNTNTT...','...TTTTTTTTTT...','....NYYYYYYN....','....NYYYYYYN....','....NYYYYYYN....','.....NYYYYN.....','.....NYYYYN.....','......NYYN......','.......NN.......','................','................'],
  'autumn-2':[
   '......KKKK......','.....K....K.....','.....K....K.....','......KKKK......','.....TTTTTT.....','....TTTTTTTT....','....KYYYYYYK....','....KYWYYWYK....','....KYWYYWYK....','....KYWYYWYK....','....KYYWWYYK....','....KYYYYYYK....','....TTTTTTTT....','.....TTTTTT.....','................','................'],
  'halloween-0':[
   '................','......KKKK......','.....KWWWWK.....','....KWWWWWWK....','...KWWWWWWWWK...','...KWKKWWKKWK...','...KWKKWWKKWK...','...KWWWWWWWWK...','...KWWWKKWWWK...','..KWWWWWWWWWWK..','..KWWWWWWWWWWK..','..KWWWWWWWWWWK..','...KWKKWWKKWK...','....K..KK..K....','................','................'],
  'halloween-1':[
   '.......GG.......','......GG........','....KKKKKKKK....','...KOOOYYOOOK...','..KOOOYYYYOOOK..','.KOOOOKYYKOOOOK.','.KOOKKKYYKKKOOK.','.KOOOOOYYOOOOOK.','.KOOOOKYYKOOOOK.','.KOKKOOYYOOKKOK.','.KOOKKKKKKKKOOK.','..KOOOKYYKOOOK..','...KOOOYYOOOK...','....KKKKKKKK....','................','................'],
  'halloween-2':[
   '........KKKK....','.......KVVVK....','......KVVVK.....','......KVVVK.....','.....KVVHVK.....','.....KVHVVK.....','....KVVHVVVK....','....KVHVVVVK....','...KRRRRRRRRK...','...KRRRYYRRRK...','..KRRRRYYRRRRK..','.KKVVVVVVVVVVKK.','KHVVVVVVVVVVVVVK','.KKKKKKKKKKKKKK.','................','................'],
  'thanksgiving-0':[
   '................','........NN......','......NNYYN.....','.....NYYYYN.....','....NYYYNYYN....','...NYYYYNYYN....','...NYYYNYYYN....','...NYYNYYYN.....','....NNYYYN......','.....NYYN.......','.....TNN........','....T...........','...T............','................','................','................'],
  'thanksgiving-1':[
   '................','................','......YYY.......','.....YOOOY......','....YOOOOWY.....','...YOOOOWWWY....','..YOOOOOWWWOY...','.YOOOOOOOOOOOY..','.YYYYYYYYYYYYY..','.NYYYYYYYYYYYN..','.NOOOOOOOOOOON..','..NNNNNNNNNNN...','...SSSSSSSSS....','................','................','................'],
  'thanksgiving-2':[
   '......TTTT......','....TT....TT....','...T........T...','...T..G..GG.T...','...T.RRR.YYYT...','...T.RPRYYYYT...','...TOOOOYYYYT...','..TTTTTTTTTTTT..','..TNNYNNYNNYNT..','...TYNNYNNYNT...','...TNNYNNYNNT...','...TYNNYNNYNT...','....TTTTTTTT....','................','................','................'],
  'christmas-0':[
   '................','.......BB.......','..B....BB....B..','...B...BB...B...','....B..BB..B....','.....BBBBBB.....','......BBBB......','.BBBBBBBBBBBBBB.','.BBBBBBBBBBBBBB.','......BBBB......','.....BBBBBB.....','....B..BB..B....','...B...BB...B...','..B....BB....B..','.......BB.......','................'],
  'christmas-1':[
   '................','......GG........','.....G..G.......','....KWWWWWWK....','....KSSSSSSK....','....KRRRRRRK....','....KRRPRRRK....','....KRRPRRRK....','....KRRRRRRK....','...KRRRRRRRK....','..KRRRRRRRRK....','.KWWRRRRRRK.....','.KWWWRRRRK......','..KKKKKKK.......','................','................'],
  'christmas-2':[
   '......IIII......','....IIWWWWII....','...IWWWWWWWWI...','..IWWWYWWWWWWI..','..IWWYYYWWWSWI..','..IWWSGWWWWWWI..','..IWWGGGWWWSWI..','..IWGGGGGWWWWI..','..IWWGGGWWWSWI..','...IGGGGGWWWI...','....IWTWWWWI....','....TTTTTTTT....','...TRRRRRRRRT...','...TRRYYYYRRT...','....TTTTTTTT....','................']
 };
 const assets={};
 for(const [key,rows] of Object.entries(drawings)){
  const body=rows.flatMap((row,y)=>[...row].map((c,x)=>colors[c]?`<rect x="${x}" y="${y}" width="1" height="1" fill="${colors[c]}"/>`:'')).join('');
  assets['season-'+key]={viewBox:'0 0 16 16',body};
 }
 window.DeskSeasonalSprites=Object.freeze(assets);
})();
