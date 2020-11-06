/* This file contains functions that measure the performance
   of parallel I/O using the mpy2 message passing package in Yorick
   for coordination.

   1) Open a non-binary file (f=create()) and write large arrays with
      _write. This bypasses the caching yorick uses for binary files.
   2) Same as (1) but with a large number of scalars in addition to
      the large arrays.
   3) Open a pdb file (f=createb()) and write large arrays to it with
      save,f,var.
   4) Same as (3) but starting with a large number of scalars and then
      writing large arrays.
   5) Same as (4) but with the scalars and large arrays intermingled.
      Yorick has 16 cache blocks so alternate between large and small
      more than 16 times to assess the effects of having to seak
      backwards in the file to flush the cache blocks.
   6) Same as (5) but with processors writing in ngroup groups.
*/

/* ngroup is used to determine how many processes
   write a checkpoint at one time in pdb_multi. */
ngroup= 4;        /* number of I/O groups */
basedir= "/p/lustre1/langer1/pf3d/iotest";

per_proc= 1;   // If non-zero, each process has its own directory
top_tier= 4;   // If per process directories, there will be this many
               // top level directories in the procs directory.
size= 0;

dbgio= 0;      // If set, get debug output

func mpio(void)
{
  extern mydir, per_proc, smallsize, tim_mg, tim_mg_pdb, tim_mg_small;
  extern tim_dir, tim_scdir, tim_pdb, tim_scpdb;
  extern bigsize, numfloat, numcmplx, scalarsper, iseq, ngroup;
  extern totbyte, sctotbyte, smalltotbyte, rate_dir, rate_scdir;
  extern rate_pdb, rate_scpdb, rate_mg_pdb, rate_mg_small;
  extern totrate_dir, totrate_scdir, totrate_pdb;
  extern totrate_scpdb, totrate_mg_pdb, totrate_mg_small, effrate_dir;
  extern effrate_scdir, effrate_pdb, effrate_scpdb, effrate_mg_pdb, effrate_mg_small;
  extern twall_dir, twall_scdir, twall_pdb, twall_scpdb, twall_mg_pdb, twall_mg_small;

  bigsize= 3000000;  /* big arrays have this many elements */
  numfloat= 14;      /* the number of large arrays to write */
  numcmplx= 10;      /* the number of large arrays that are complex */
  scalarsper= 4;     /* number of scalar variables for every array */
  tim_dir= tim_scdir= tim_pdb= tim_scpdb= array(0.0, mp_size);

  // Hand out sizes etc.
  mp_exec,"mp_prep,0";
  
  /* Form I/O groups*/
  mp_exec,"set_grp,0";
  /* communicate the size and number of arrays to all nodes */
  start_tim= fin_tim= array(0.0, 3);
  write,"Number of processes is "+pr1(mp_size);
  write,"time is "+pr1(timestamp());
  write,"base directory is "+basedir;
  iseq= 0;
  // make the top level directory for this "checkpoint"
  dirnam= basedir+"s"+totxt(iseq);
  write,"dirnam is "+dirnam;
  mkdirp,dirnam;
  // make the sub-directories for this dump
  mp_exec,"make_dir,iseq";

  use_rand= 1;
  if(use_rand) {
    write,"Initialize arrays with random values to prevent file compresion";
    mp_exec, "make_vars_rand, bigsize";
  } else {
    write,"Initialize arrays with zeroes";
    mp_exec, "make_vars, bigsize";
  }
  write,"make vars complete\n";

  /* run all tests */

  timer, start_tim;
  mp_exec,"direct_big, numfloat, numcmplx";
  timer, fin_tim;
  twall_dir= (fin_tim-start_tim)(3);
  write,"direct big complete";

  timer, start_tim;
  mp_exec,"direct_bigsmall, numfloat, numcmplx, scalarsper";
  timer, fin_tim;
  twall_scdir= (fin_tim-start_tim)(3);
  write,"direct big+small complete";

  timer, start_tim;
  mp_exec,"pdb_big, numfloat";
  timer, fin_tim;
  twall_pdb= (fin_tim-start_tim)(3);
  write,"pdb big complete";

  timer, start_tim;
  mp_exec,"pdb_bigsmall, numfloat";
  timer, fin_tim;
  twall_scpdb= (fin_tim-start_tim)(3);
  write,"pdb big+small complete";
    
  /* This is a multi-group I/O test. Members of an I/O group
     write their data to disk for restart dumps when told to by
     the group leader. */
  /* The group leader writes the data to disk for spec and hist dumps. */
  timer, start_tim;
  mp_exec,"pdb_multi, 1";
  timer, fin_tim;
  twall_mg_pdb= (fin_tim-start_tim)(3);
  write,"pdb multi-group complete";
  tim_mg_pdb= tim_mg;
  
  /* Repeat the multi-group test with smaller files. */
  timer, start_tim;
  mp_exec,"pdb_multi, 2";
  timer, fin_tim;
  twall_mg_small= (fin_tim-start_tim)(3);
  write,"small multi-group complete";
  tim_mg_small= tim_mg;
  
  totbyte= bigsize*sizeof(float)*(numfloat+2*numcmplx);
  sctotbyte= totbyte+scalarsper*sizeof(double)*(numfloat+numcmplx);
  smalltotbyte= smallsize*sizeof(float)*(numfloat+2*numcmplx)+
                scalarsper*sizeof(double)*(numfloat+numcmplx);
  rate_dir= totbyte/(tim_dir+1.0e-6)*1.0e-6;  // rate in MB/s
  rate_scdir= sctotbyte/(tim_scdir+1.0e-6)*1.0e-6;  // rate in MB/s
  rate_pdb= totbyte/(tim_pdb+1.0e-6)*1.0e-6;  // rate in MB/s
  rate_scpdb= sctotbyte/(tim_scpdb+1.0e-6)*1.0e-6;  // rate in MB/s
  // multi-group files are larger than individual files because
  // they have multiple domains
  tim_mg_pdb= getall(tim_mg_pdb);
  tim_mg_small= getall(tim_mg_small);
  rate_mg_pdb= totbyte/(tim_mg_pdb+1.0e-6)*1.0e-6;  // rate in MB/s
  rate_mg_small= smalltotbyte/(tim_mg_small+1.0e-6)*1.0e-6;  // rate in MB/s
  write,"\nRates for multi-group are not directly comparable because I/O may occur in stages";
  msg= swrite(format="rank 0 direct big array                         time=%8.2f rate=%8.2f MB/s", tim_dir(1), rate_dir(1));
  write,msg;
  msg= swrite(format="rank 0 direct big array and scalars            time= %8.2f rate=%8.2f MB/s", tim_scdir(1), rate_scdir(1));
  write,msg;
  msg= swrite(format="rank 0 pdb big array                            time=%8.2f rate=%8.2f MB/s", tim_pdb(1), rate_pdb(1));
  write,msg;
  msg= swrite(format="rank 0 pdb big array and scalars                time=%8.2f rate=%8.2f MB/s", tim_scpdb(1), rate_scpdb(1));
  write,msg;
  msg= swrite(format="rank 0 pdb multi-group big array and scalars   time= %7.2f rate= %7.2f MB/s", tim_mg_pdb(1), rate_mg_pdb(1));
  write,msg;
  msg= swrite(format="rank 0 pdb multi-group small array and scalars  time= %7.2f rate= %7.2f MB/s", tim_mg_small(1), rate_mg_small(1));
  write,msg;

  effrate_dir=   mp_size*totbyte/(twall_dir  +1.0e-6)*1.0e-6;
  effrate_scdir= mp_size*sctotbyte/(twall_scdir+1.0e-6)*1.0e-6;
  effrate_pdb=   mp_size*totbyte/(twall_pdb  +1.0e-6)*1.0e-6;
  effrate_scpdb= mp_size*sctotbyte/(twall_scpdb+1.0e-6)*1.0e-6;
  // a full set of multi-group files has the same amount of data
  // as a set of private files.
  effrate_mg_pdb= mp_size*totbyte/(twall_mg_pdb+1.0e-6)*1.0e-6;
  effrate_mg_small= mp_size*smalltotbyte/(twall_mg_small+1.0e-6)*1.0e-6;
  write,"";
  msg= swrite(format="effective direct big array rate=                        %8.2f MB/s", effrate_dir(1));
  write,msg;
  msg= swrite(format="effective direct big array and scalars rate=            %8.2f MB/s", effrate_scdir(1));
  write,msg;
  msg= swrite(format="effective pdb big array rate=                           %8.2f MB/s", effrate_pdb(1));
  write,msg;
  msg= swrite(format="effective pdb big array and scalars rate=               %8.2f MB/s", effrate_scpdb(1));
  write,msg;
  msg= swrite(format="effective pdb multi-group big array and scalars rate=   %8.2f MB/s", effrate_mg_pdb(1));
  write,msg;
  msg= swrite(format="effective pdb multi-group small array and scalars rate= %8.2f MB/s", effrate_mg_small(1));
  write,msg;
  write,"\nThe number of I/O groups is",ngroup;

  f= createb("test_res.pdb");
  save,f, tim_dir, tim_scdir, tim_pdb, tim_scpdb, tim_mg_pdb;
  save,f, twall_dir, twall_scdir, twall_pdb, twall_scpdb, twall_mg_pdb;
  save,f, bigsize, numfloat, numcmplx, scalarsper, ngroup;
  save,f, rate_dir, rate_scdir, rate_pdb, rate_scpdb, rate_mg_pdb;
  save,f, effrate_dir, effrate_scdir, effrate_pdb, effrate_scpdb, effrate_mg_pdb;
  save,f, tim_mg_small, twall_mg_small, rate_mg_small, effrate_mg_small;
  close,f;
}

func set_dir
{
  extern bigsize, numfloat, numcmplx, scalarsper, per_proc, top_tier, basedir;
  extern mydir, mytier, dbgio;
  
  if(top_tier) {
    mytier= mp_rank % top_tier;
    mydir= basedir+"/tier"+pr1(mytier)+"/proc"+pr1(mp_rank);
    if(dbgio) write,"Rank "+totxt(mp_rank)+" has directory "+mydir;
    if(mp_rank < top_tier) {
      /* make the per process directories assigned to this process */
      for(ir= mp_rank; ir < mp_size; ir += top_tier) {
        dirnam= basedir+"/tier"+pr1(mp_rank)+"/proc"+pr1(ir);
        if(dbgio) write,"creating directory "+dirnam;
        mkdir,dirnam;
      }
    }
  } else {
    mydir= basedir+"/proc"+pr1(mp_rank);
  }
}

func make_vars(size)
{
  extern var1, var2, var3, var4, var5, var6, var7, var8, var9;
  extern var10, var11, var12, var13, var14, var15, var16, var17;
  extern var18, var19, var20, var21, var22, var23, var24;
  extern svar1, svar2, svar3, svar4, svar5, svar6, svar7, svar8, svar9;
  extern svar10, svar11, svar12, svar13, svar14, svar15, svar16, svar17;
  extern svar18, svar19, svar20, svar21, svar22, svar23, svar24;
  extern s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
  extern s10, s11, s12, s13, s14, s15, s16, s17, s18, s19;
  extern s20, s21, s22, s23, s24, s25, s26, s27, s28, s29;
  extern s30, s31, s32, s33, s34, s35, s36, s37, s38, s39;
  extern s40, s41, s42, s43, s44, s45, s46, s47, s48, s49;
  extern s50, s51, s52, s53, s54, s55, s56, s57, s58, s59;
  extern s60, s61, s62, s63, s64, s65, s66, s67, s68, s69;
  extern s70, s71, s72, s73, s74, s75, s76, s77, s78, s79;
  extern s80, s81, s82, s83, s84, s85, s86, s87, s88, s89;
  extern s90, s91, s92, s93, s94, s95;
  extern var, cvar;
  extern siz_varn, siz_scalar, smallsize;

  /* Create float and complex arrays and double scalars for future use. */

  mp_handout,size;
  smallsize= size/10;
  var1= var2= var3= var4= var5= var6= var7= var8= var9= array(float, size);
  var10= var11= var12= var13= var14= array(float, size);
  var15= var16= var17= var18= var19= array(float, 2, size);
  var20= var21= var22= var23= var24= array(float, 2, size);
  svar1= svar2= svar3= svar4= svar5= svar6= svar7= svar8= svar9= array(float, size);
  svar10= svar11= svar12= svar13= svar14= array(float, smallsize);
  svar15= svar16= svar17= svar18= svar19= array(float, 2, smallsize);
  svar20= svar21= svar22= svar23= svar24= array(float, 2, smallsize);
  s0= s1= s2= s3= s4= s5= s6= s7= s8= s9= 0.0;
  s10= s11= s12= s13= s14= s15= s16= s17= s18= s19= 0.0;
  s20= s21= s22= s23= s24= s25= s26= s27= s28= s29= 0.0;
  s30= s31= s32= s33= s34= s35= s36= s37= s38= s39= 0.0;
  s40= s41= s42= s43= s44= s45= s46= s47= s48= s49= 0.0;
  s50= s51= s52= s53= s54= s55= s56= s57= s58= s59= 0.0;
  s60= s61= s62= s63= s64= s65= s66= s67= s68= s69= 0.0;
  s70= s71= s72= s73= s74= s75= s76= s77= s78= s79= 0.0;
  s80= s81= s82= s83= s84= s85= s86= s87= s88= s89= 0.0;
  s90= s91= s92= s93= s94= s95= 0.0;
  siz_scalar= sizeof(s0)*96;

  var= array(float, size);
  svar= array(float, smallsize);
  cvar= array(float, 2, size);

  // make sure all processes have finished
  mp_handin,size;
}

func make_vars_rand(size)
{
  extern var1, var2, var3, var4, var5, var6, var7, var8, var9;
  extern var10, var11, var12, var13, var14, var15, var16, var17;
  extern var18, var19, var20, var21, var22, var23, var24;
  extern svar1, svar2, svar3, svar4, svar5, svar6, svar7, svar8, svar9;
  extern svar10, svar11, svar12, svar13, svar14, svar15, svar16, svar17;
  extern svar18, svar19, svar20, svar21, svar22, svar23, svar24;
  extern s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
  extern s10, s11, s12, s13, s14, s15, s16, s17, s18, s19;
  extern s20, s21, s22, s23, s24, s25, s26, s27, s28, s29;
  extern s30, s31, s32, s33, s34, s35, s36, s37, s38, s39;
  extern s40, s41, s42, s43, s44, s45, s46, s47, s48, s49;
  extern s50, s51, s52, s53, s54, s55, s56, s57, s58, s59;
  extern s60, s61, s62, s63, s64, s65, s66, s67, s68, s69;
  extern s70, s71, s72, s73, s74, s75, s76, s77, s78, s79;
  extern s80, s81, s82, s83, s84, s85, s86, s87, s88, s89;
  extern s90, s91, s92, s93, s94, s95;
  extern var, cvar;
  extern siz_varn, siz_scalar, smallsize;

  /* Create float and complex arrays and double scalars for future use. */

  mp_handout,size;
  smallsize= size/10;
  var1= float(random([1,size]));
  var2= float(random([1,size]));
  var3= float(random([1,size]));
  var4= float(random([1,size]));
  var5= float(random([1,size]));
  var6= float(random([1,size]));
  var7= float(random([1,size]));
  var8= float(random([1,size]));
  var9= float(random([1,size]));
  var10= float(random([1,size]));
  var11= float(random([1,size]));
  var12= float(random([1,size]));
  var13= float(random([1,size]));
  var14= float(random([1,size]));
  var15= float(random([2,2,size]));
  var16= float(random([2,2,size]));
  var17= float(random([2,2,size]));
  var18= float(random([2,2,size]));
  var19= float(random([2,2,size]));
  var20= float(random([2,2,size]));
  var21= float(random([2,2,size]));
  var22= float(random([2,2,size]));
  var23= float(random([2,2,size]));
  var24= float(random([2,2,size]));
  svar1= float(random([1,smallsize]));
  svar2= float(random([1,smallsize]));
  svar3= float(random([1,smallsize]));
  svar4= float(random([1,smallsize]));
  svar5= float(random([1,smallsize]));
  svar6= float(random([1,smallsize]));
  svar7= float(random([1,smallsize]));
  svar8= float(random([1,smallsize]));
  svar9= float(random([1,smallsize]));
  svar10= float(random([1,smallsize]));
  svar11= float(random([1,smallsize]));
  svar12= float(random([1,smallsize]));
  svar13= float(random([1,smallsize]));
  svar14= float(random([1,smallsize]));
  svar15= float(random([2,2,smallsize]));
  svar16= float(random([2,2,smallsize]));
  svar17= float(random([2,2,smallsize]));
  svar18= float(random([2,2,smallsize]));
  svar19= float(random([2,2,smallsize]));
  svar20= float(random([2,2,smallsize]));
  svar21= float(random([2,2,smallsize]));
  svar22= float(random([2,2,smallsize]));
  svar23= float(random([2,2,smallsize]));
  svar24= float(random([2,2,smallsize]));
  s0= s1= s2= s3= s4= s5= s6= s7= s8= s9= 0.0;
  s10= s11= s12= s13= s14= s15= s16= s17= s18= s19= 0.0;
  s20= s21= s22= s23= s24= s25= s26= s27= s28= s29= 0.0;
  s30= s31= s32= s33= s34= s35= s36= s37= s38= s39= 0.0;
  s40= s41= s42= s43= s44= s45= s46= s47= s48= s49= 0.0;
  s50= s51= s52= s53= s54= s55= s56= s57= s58= s59= 0.0;
  s60= s61= s62= s63= s64= s65= s66= s67= s68= s69= 0.0;
  s70= s71= s72= s73= s74= s75= s76= s77= s78= s79= 0.0;
  s80= s81= s82= s83= s84= s85= s86= s87= s88= s89= 0.0;
  s90= s91= s92= s93= s94= s95= 0.0;
  siz_scalar= sizeof(s0)*96;

  var= array(float, size);
  svar= array(float, smallsize);
  cvar= array(float, 2, size);

  // make sure all processes have finished
  mp_handin,size;
}

func mp_prep(idum)
{
  extern bigsize, numfloat, numcmplx, scalarsper, per_proc, top_tier, basedir;
  extern ngroup;

  if(mp_size > 1) {
    mp_handout, bigsize, numfloat, numcmplx, scalarsper, per_proc, top_tier, basedir, ngroup;
  }
}

func direct_big(numfloat, numcmplx)
{
  extern mydir, tim_dir;
  extern var, cvar;

  /* Create a "text" file and write numfloat float arrays
     and numplx complex arrays with size elements each. */

  mp_handout, numfloat, numcmplx;
  off= 0;
  fnam= swrite(format="%s/file_dir_%d", mydir, mp_rank);

  start_tim= fin_tim= array(0.0, 3);
  timer, start_tim;
  f= open(fnam, "wb");
  for(i= 1; i <= numfloat; i++) {
    _write,f,off,var;
    off += sizeof(var);
  }
  for(i= 1; i <= numcmplx; i++) {
    _write,f,off,cvar;
    off += sizeof(cvar);
  }
  close,f;
  timer,fin_tim;
  /* the wall clock time in seconds needed to write the file */
  walltim= (fin_tim - start_tim)(3);

  if(!mp_rank) {
    // collect the times
    tim_dir= array(0.0, mp_size);
    tim_dir(1)= walltim;
    for(i= 1; i < mp_size; i++) {
      tim_dir(i+1)= mp_recv(i);
    }
  } else {
    mp_send, 0, walltim;
  }
}

func direct_bigsmall(numfloat, numcmplx, scalarsper)
{
  extern mydir, tim_scdir;
  extern var, cvar;

  /* Create a "text" file and write numfloat float arrays
     and numplx complex float sized arrays with size elements each. 
     Intersperse scalarsper scalar double variables between big arrays. */

  mp_handout, numfloat, numcmplx, scalarsper;
  scalar= 1.1;
  off= 0;
  fnam= swrite(format="%s/file_scdir_%d", mydir, mp_rank);

  start_tim= fin_tim= array(0.0, 3);
  timer, start_tim;
  f= open(fnam, "wb");
  for(i= 1; i <= numfloat; i++) {
    _write,f,off,var;
    off += sizeof(var);
    for(j= 1; j <= scalarsper; j++) {
      _write,f,off,scalar;
      off += sizeof(scalar);
    }
  }
  for(i= 1; i <= numfloat; i++) {
    _write,f,off,cvar;
    off += sizeof(cvar);
    for(j= 1; j <= scalarsper; j++) {
      _write,f,off,scalar;
      off += sizeof(scalar);
    }
  }
  close,f;
  timer,fin_tim;
  /* return the wall clock time in seconds needed to write the file */
  walltim= (fin_tim - start_tim)(3);

  if(!mp_rank) {
    // collect the times
    tim_scdir= array(0.0, mp_size);
    tim_scdir(1)= walltim;
    for(i= 1; i < mp_size; i++) {
      tim_scdir(i+1)= mp_recv(i);
      // This relies on the group leaders being the first ngroup processes
    }
  } else {
    mp_send, 0, walltim;
  }
}

func pdb_big(num)
{
  extern mydir, tim_pdb;
  extern var1, var2, var3, var4, var5, var6, var7, var8, var9;
  extern var10, var11, var12, var13, var14, var15, var16, var17;
  extern var18, var19, var20, var21, var22, var23, var24;

  /* create a pdb file and write float arrays, 
     and (perhaps) complex float  arrays */

  mp_handout,num;
  fnam= swrite(format="%s/file_pdb_%d", mydir, mp_rank);

  start_tim= fin_tim= array(0.0, 3);
  timer, start_tim;
  f= createb(fnam);
  save,f,var1;
  save,f,var2;
  save,f,var3;
  save,f,var4;
  save,f,var5;
  save,f,var6;
  save,f,var7;
  save,f,var8;
  save,f,var9;
  save,f,var10;
  save,f,var11;
  save,f,var12;
  save,f,var13;
  save,f,var14;
  save,f,var15;
  save,f,var16;
  save,f,var17;
  save,f,var18;
  save,f,var19;
  save,f,var20;
  save,f,var21;
  save,f,var22;
  save,f,var23;
  save,f,var24;
  close,f;
  timer,fin_tim;
  /* return the wall clock time in seconds needed to write the file */
  walltim= (fin_tim - start_tim)(3);

  if(!mp_rank) {
    // collect the times
    tim_pdb= array(0.0, mp_size);
    tim_pdb(1)= walltim;
    for(i= 1; i < mp_size; i++) {
      tim_pdb(i+1)= mp_recv(i);
      // This relies on the group leaders being the first ngroup processes
    }
  } else {
    mp_send, 0, walltim;
  }
}

func pdb_bigsmall(num)
{
  extern mydir, tim_scpdb;
  extern var1, var2, var3, var4, var5, var6, var7, var8, var9;
  extern var10, var11, var12, var13, var14, var15, var16, var17;
  extern var18, var19, var20, var21, var22, var23, var24;
  extern s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
  extern s10, s11, s12, s13, s14, s15, s16, s17, s18, s19;
  extern s20, s21, s22, s23, s24, s25, s26, s27, s28, s29;
  extern s30, s31, s32, s33, s34, s35, s36, s37, s38, s39;
  extern s40, s41, s42, s43, s44, s45, s46, s47, s48, s49;
  extern s50, s51, s52, s53, s54, s55, s56, s57, s58, s59;
  extern s60, s61, s62, s63, s64, s65, s66, s67, s68, s69;
  extern s70, s71, s72, s73, s74, s75, s76, s77, s78, s79;
  extern s80, s81, s82, s83, s84, s85, s86, s87, s88, s89;
  extern s90, s91, s92, s93, s94, s95;

  /* create a pdb file and write float arrays, scalars, 
     and (perhaps) complex float  arrays */

  mp_handout,num;
  fnam= swrite(format="%s/file_scpdb_%d", mydir, mp_rank);

  start_tim= fin_tim= array(0.0, 3);
  timer, start_tim;
  f= createb(fnam);
  sav_multi,f;
  close,f;
  timer,fin_tim;
  /* return the wall clock time in seconds needed to write the file */
  walltim= (fin_tim - start_tim)(3);

  if(!mp_rank) {
    // collect the times
    tim_scpdb= array(0.0, mp_size);
    tim_scpdb(1)= walltim;
    for(i= 1; i < mp_size; i++) {
      tim_scpdb(i+1)= mp_recv(i);
      // This relies on the group leaders being the first ngroup processes
    }
  } else {
    mp_send, 0, walltim;
  }
}

func sav_multi(f)
{
  extern fdata;
  extern var1, var2, var3, var4, var5, var6, var7, var8, var9;
  extern var10, var11, var12, var13, var14, var15, var16, var17;
  extern var18, var19, var20, var21, var22, var23, var24;
  extern s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
  extern s10, s11, s12, s13, s14, s15, s16, s17, s18, s19;
  extern s20, s21, s22, s23, s24, s25, s26, s27, s28, s29;
  extern s30, s31, s32, s33, s34, s35, s36, s37, s38, s39;
  extern s40, s41, s42, s43, s44, s45, s46, s47, s48, s49;
  extern s50, s51, s52, s53, s54, s55, s56, s57, s58, s59;
  extern s60, s61, s62, s63, s64, s65, s66, s67, s68, s69;
  extern s70, s71, s72, s73, s74, s75, s76, s77, s78, s79;
  extern s80, s81, s82, s83, s84, s85, s86, s87, s88, s89;
  extern s90, s91, s92, s93, s94, s95;
  
  /* write float arrays, scalars, 
     and (perhaps) complex float arrays to a pdb file */

  save,f,var1;
  save,f,s0,s1,s2,s3;
  save,f,var2;
  save,f,s4,s5,s6,s7;
  save,f,var3;
  save,f,s8,s9,s10,s11;
  save,f,var4;
  save,f,s12,s13,s14,s15;
  save,f,var5;
  save,f,s16,s17,s18,s19;
  save,f,var6;
  save,f,s20,s21,s22,s23;
  save,f,var7;
  save,f,s24,s25,s26,s27;
  save,f,var8;
  save,f,s28,s29,s30,s31;
  save,f,var9;
  save,f,s32,s33,s34,s35;
  save,f,var10;
  save,f,s36,s37,s38,s39;
  save,f,var11;
  save,f,s40,s41,s42,s43;
  save,f,var12;
  save,f,s44,s45,s46,s47;
  save,f,var13;
  save,f,s48,s49,s50,s51;
  save,f,var14;
  save,f,s52,s53,s54,s55;
  save,f,var15;
  save,f,s56,s57,s58,s59;
  save,f,var16;
  save,f,s60,s61,s62,s63;
  save,f,var17;
  save,f,s64,s65,s66,s67;
  save,f,var18;
  save,f,s68,s69,s70,s71;
  save,f,var19;
  save,f,s72,s73,s74,s75;
  save,f,var20;
  save,f,s76,s77,s78,s79;
  save,f,var21;
  save,f,s80,s81,s82,s83;
  save,f,var22;
  save,f,s84,s85,s86,s87;
  save,f,var23;
  save,f,s88,s89,s90,s91;
  save,f,var24;
  save,f,s92,s93,s94,s95;
}

func multi_small(f)
{
  extern fdata;
  extern svar1, svar2, svar3, svar4, svar5, svar6, svar7, svar8, svar9;
  extern svar10, svar11, svar12, svar13, svar14, svar15, svar16, svar17;
  extern svar18, svar19, svar20, svar21, svar22, svar23, svar24;
  extern s0, s1, s2, s3, s4, s5, s6, s7, s8, s9;
  extern s10, s11, s12, s13, s14, s15, s16, s17, s18, s19;
  extern s20, s21, s22, s23, s24, s25, s26, s27, s28, s29;
  extern s30, s31, s32, s33, s34, s35, s36, s37, s38, s39;
  extern s40, s41, s42, s43, s44, s45, s46, s47, s48, s49;
  extern s50, s51, s52, s53, s54, s55, s56, s57, s58, s59;
  extern s60, s61, s62, s63, s64, s65, s66, s67, s68, s69;
  extern s70, s71, s72, s73, s74, s75, s76, s77, s78, s79;
  extern s80, s81, s82, s83, s84, s85, s86, s87, s88, s89;
  extern s90, s91, s92, s93, s94, s95;
  
  /* write float arrays, scalars, 
     and (perhaps) complex float arrays to a pdb file */

  save,f,svar1;
  save,f,s0,s1,s2,s3;
  save,f,svar2;
  save,f,s4,s5,s6,s7;
  save,f,svar3;
  save,f,s8,s9,s10,s11;
  save,f,svar4;
  save,f,s12,s13,s14,s15;
  save,f,svar5;
  save,f,s16,s17,s18,s19;
  save,f,svar6;
  save,f,s20,s21,s22,s23;
  save,f,svar7;
  save,f,s24,s25,s26,s27;
  save,f,svar8;
  save,f,s28,s29,s30,s31;
  save,f,svar9;
  save,f,s32,s33,s34,s35;
  save,f,svar10;
  save,f,s36,s37,s38,s39;
  save,f,svar11;
  save,f,s40,s41,s42,s43;
  save,f,svar12;
  save,f,s44,s45,s46,s47;
  save,f,svar13;
  save,f,s48,s49,s50,s51;
  save,f,svar14;
  save,f,s52,s53,s54,s55;
  save,f,svar15;
  save,f,s56,s57,s58,s59;
  save,f,svar16;
  save,f,s60,s61,s62,s63;
  save,f,svar17;
  save,f,s64,s65,s66,s67;
  save,f,svar18;
  save,f,s68,s69,s70,s71;
  save,f,svar19;
  save,f,s72,s73,s74,s75;
  save,f,svar20;
  save,f,s76,s77,s78,s79;
  save,f,svar21;
  save,f,s80,s81,s82,s83;
  save,f,svar22;
  save,f,s84,s85,s86,s87;
  save,f,svar23;
  save,f,s88,s89,s90,s91;
  save,f,svar24;
  save,f,s92,s93,s94,s95;
}

func fnam_disk(dir, rank, dumptype)
{
  if(dumptype == 2) {
    fnam= swrite(format="%s/file_multi_small_%d", dir, rank);
  } else {
    fnam= swrite(format="%s/file_multi_%d", dir, rank);
  }
  return fnam;
}

func set_grp(idum)
{
  extern am_leader, my_leader, ngroup, grpsiz;
  extern dbgio;
  
  am_leader= (mp_rank < ngroup);
  my_leader= mp_rank % ngroup;
  if(dbgio) write,"Rank "+totxt(mp_rank)+" has am_leader="+totxt(am_leader)+" and my_leader="+totxt(my_leader);
  if(am_leader) {
    //  the size of this group
    grpsiz= 1;
    for(i= mp_rank+ngroup; i < mp_size; i += ngroup) {
        grpsiz++;
    }
    if(dbgio) write,"Rank "+totxt(mp_rank)+" has grpsiz="+totxt(grpsiz);
  }
}

func my_dir(iseq)
{
  extern am_leader, my_leader, basedir;

  dirnam= basedir+"s"+totxt(iseq)+"/chunk"+totxt(my_leader);

  return dirnam;
}

func make_dir(iseq)
{
  extern am_leader, my_leader, basedir, mydir, dbgio;

  mp_handout,iseq;
  mydir= my_dir(iseq);
  if(dbgio) write,"Rank "+totxt(mp_rank)+" has directory "+mydir;
  if(am_leader) {
    /* make the directory for this group */
    mkdir,mydir;
  }
  return;
}

func pdb_multi(dumptype)
{
  extern mydir, tim_mg, ngroup, grpsiz;

  if(is_void(dumptype)) dumptype= 1;
  mp_handout,dumptype;
  if(!mp_rank) {
    // tell all groups to "start"
    for(i= 1; i < ngroup; i++) {
      mp_send,i,0;
    }
    // Save the "file" for rank zero to disk.
    // WARNING - this needs to go after the other groups have been
    // "started" or it will be anomalously fast
    walltim= write_data(dumptype);
    write,"Rank 0 has wall time "+totxt(walltim);

    // coordinate I/O for rank zero's group
    // Only one process in the group dumps at any one time
    tim_grp= array(0.0, grpsiz);
    tim_grp(1)= walltim;
    idgrp= 2;
    for(i= mp_rank+ngroup; i < mp_size; i += ngroup) {
      mp_send,i,0;
      tim= mp_recv(i);
      tim_grp(idgrp)= tim;
      idgrp++;
    }
    tim_mg= array(pointer, ngroup);
    tim_mg(1)= &tim_grp;
    for(i= 1; i < ngroup; i++) {
      ftimes= mp_recv(i);
      tim_mg(i+1)= &ftimes;
    }
  } else {
    am_leader= (mp_rank < ngroup);
    my_leader= mp_rank % ngroup;
    if(am_leader) {
      go= mp_recv(0);
      // save the "file" for this domain to disk
      walltim= write_data(dumptype);
      // coordinate I/O for rank zero's group
      // Only one process in the group dumps at any one time
      tim_grp= array(0.0, grpsiz);
      tim_grp(1)= walltim;
      idgrp= 2;
      for(i= mp_rank+ngroup; i < mp_size; i += ngroup) {
        mp_send,i,0;
        tim= mp_recv(i);
        tim_grp(idgrp)= tim;
        idgrp++;
      }
      mp_send, 0, tim_grp;
    } else {
      go= mp_recv(my_leader);
      // save the "file" for this domain to disk
      walltim= write_data(dumptype);
      mp_send, my_leader, walltim;
    }
  }
}

func write_data(dumptype)
{
  extern mydir, mp_rank;
  
  start_tim= fin_tim= array(0.0, 3);
  timer, start_tim;
  fnam= fnam_disk(mydir, mp_rank, dumptype);
  fdisk= createb(fnam);
  if(dumptype == 1) {
    sav_multi, fdisk;
  } else if(dumptype == 2) {
    multi_small, fdisk;
  } else {
    write,"unrecognized dump type "+pr1(dumptype);
  }
  timer,fin_tim;
  walltim= (fin_tim - start_tim)(3);

  return walltim;
}

func sumall(ptvar)
{
  // ptvar should be an array of pointers
  if(typeof(ptvar) != "pointer") {
    error,"argument to sumall should be an array of pointers";
  }
  nn= numberof(sumall);
  thesum= 0.0;
  for(i= 0; i <= nn; i++) {
    thesum += sum(*ptvar(i));
  }
  return thesum;
}

func getall(ptvar)
{
  // ptvar should be an array of pointers
  if(typeof(ptvar) != "pointer") {
    error,"argument to getall should be an array of pointers";
  }
  nn= numberof(ptvar);
  thevals= [];
  for(i= 1; i <= nn; i++) {
    arr= *ptvar(i);
    thevals= grow(thevals,arr);
  }
  return thevals;
}

if(!mp_rank) write,"Type: mpio    to run the test";
