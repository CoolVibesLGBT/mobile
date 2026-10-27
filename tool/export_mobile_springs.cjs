const fs=require('fs');
const root='/Users/ersanyakit/Documents/coolvibes/coolvibes/mobile/coolvibes/node_modules/';
const ts=require(root+'typescript');
const path=root+'react-native-reanimated/src/animation/spring/springUtils.ts';
const js=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
const exported={};new Function('require','exports',js)(()=>({}),exported);
const specs=[['pan',90,18,300,-150,120],['focus',100,18,90,0,0],['zoom',150,20,1,.5,0],['return',900,120,.5,1,0],['profile',120,20,0,1,0]];
const fixture=specs.map(([name,stiffness,damping,start,target,velocity])=>{
 const config={stiffness,damping,mass:4,useDuration:false};
 const values=exported.initialCalculations(stiffness,config);
 const initialEnergy = exported.getEnergy(start-target,velocity,stiffness,4);
 const samples=[.016,.1,.25,.5,1].map(t=>{
  const result=exported[values.zeta<1?'underDampedSpringCalculations':'criticallyDampedSpringCalculations']({toValue:target},{...values,x0:start-target,v0:velocity,t});
  const done=exported.isAnimationTerminatingCalculation({toValue:target,current:result.position,velocity:result.velocity,startValue:start-target,initialEnergy},{...config,energyThreshold:6e-9,overshootClamping:false});
  return {...(done?{position:target,velocity:0}:result),t};
 });
 return {name,...config,start,target,velocity,samples};
});fs.writeFileSync('test/fixtures/mobile-springs.json',JSON.stringify(fixture,null,2));
