// ------------------------------------------------------------
// Every tick.
// ------------------------------------------------------------
extend class HDPlayerPawn{
	string viewstring;
	bool canmovelegs;
	double bobvelmomentum;
	override void Tick(){
		if(!player||!player.mo||player.mo!=self){super.tick();return;} //anti-voodoodoll
		let player=self.player;

		//cache cvars as necessary
		if(!hd_nozoomlean)cachecvars();

		//check some cvars that are used to pass string commands
		CheckGiveCheat();

		int time=level.time;
		flip=time&1; //for things that must alternate every tic
		if(!(time&(1|2|4|8)))bspawnsoundsource=false;

		//for fadeout of tips
		if(specialtipalpha>0.){
			specialtipalpha-=0.1;
			if(
				specialtipalpha>999.
				&&specialtipalpha<1000.
			)specialtipalpha=specialtipalpha=12.+0.08*specialtip.length();
		}

		//fadeout effect
		UpdateBlackout();

		if(hd_voicepitch)A_SoundPitch(CHAN_VOICE,clamp(hd_voicepitch.getfloat(),0.7,1.3));

		settag(player.getusername());

		//only do anything below this while the player is alive!
		if(bkilled||health<1){
			super.Tick();
			return;
		}

		//log all new inputs
		int input=player.cmd.buttons;
		double fm=player.cmd.forwardmove;
		double sm=player.cmd.sidemove;
		isFocussing=(
			(
				input&BT_ZOOM
				||(
					input&BT_USE
					&&hd_usefocus.GetBool()
				)
			)&&!countinv("IsMoving")
		);

		//re-enable item selection after de-incapacitation
		if(
			!incapacitated
			&&(
				!invsel
				||invsel.owner!=self
			)
		){
			for(let item=inv;item!=null;item=item.inv){
				if(
					item.binvbar
				){
					invsel=item;
					break;
				}
			}
		}



		super.Tick();


		HeartTicker(fm,sm,input);
		if(inpain>0)inpain--;
		if(!player||!player.mo||player.mo!=self){super.tick();return;} //that xkcd xorg graph, but with morphing


		ApplyUserSkin();


		//update heights and strength
		if(min(getage(),time)<=1){
			double newheightmult=hd_height.getfloat();

			//allow multiplier alternative
			if(newheightmult<=10.)newheightmult*=HDCONST_DEFAULTHEIGHTCM;

			newheightmult=clamp(
				newheightmult*(1./HDCONST_DEFAULTHEIGHTCM),
				0.8,1.2
			);
			if(heightmult!=newheightmult){
				heightmult=newheightmult;
				A_SetSize(default.radius*newheightmult,height);
				scale=skinscale*newheightmult;
				fullheight=default.height*newheightmult;
				viewheight=default.viewheight*newheightmult;
				attackzoffset=default.attackzoffset*newheightmult;
				userange=default.userange*newheightmult;
				maxpocketspace=default.maxpocketspace*newheightmult;
				mass=int(default.mass*newheightmult); //yeah yeah whatever
				player.crouchfactor=0.99;
			}

			strength=basestrength();
		}


		//prevent odd screwups that leave you unable to throw grenades or something
		if(!countinv("HDFist"))GiveBasics();
		if(!player.readyweapon)A_SelectWeapon("HDFist");

		//gross hack, but i have no way of telling when a savegame is being loaded
		if(
			player
			&&player.mo
			&&player==players[consoleplayer]
			&&!countinv("PortableLiteAmp")
		)PPShader.SetEnabled("NiteVis",false);

		//same thing with scope camera
		if(!scopecamera)scopecamera=spawn("ScopeCamera",pos,ALLOW_REPLACE);
		scopecamera.target=self;


		//check if teleported
		//fastest you can voluntarily go (berserk, invuln, soulsphere) is mid-90s
		vector2 posdif=prev.xy-pos.xy;
		teleported=(
			bteleport
			||posdif dot posdif>10000
		);

		//if this is put into playermove bad things happen
		RollCheck();
		if(!incapacitated){
			JumpCheck(fm,sm);
			CrouchCheck();
		}

		//prevent some support exploits
		if(vel dot vel>1)gunbraced=false;

		//add inventory flags for inputs
		//this will be used a few times hereon in
		bool weaponbusy=(
			HDWeapon.IsBusy(self)
			||input&BT_RELOAD
			||input&BT_USER1
//			||input&BT_USER2
			||input&BT_USER3
			||input&BT_USER4
		);
		HDWeapon.SetBusy(self,weaponbusy);
		if((fm||sm)&&runwalksprint>=0&&vel!=(0,0,0))A_GiveInventory("IsMoving");
		if(striptime>0)striptime--;


		//involuntary angle stuff that should still be done during input hijack
		if(reactiontime>0){

			LowHealthJitters();

			A_SetPitch(pitch+muzzleclimb1.x,SPF_INTERPOLATE);
			A_SetAngle(angle+muzzleclimb1.y,SPF_INTERPOLATE);
			muzzleclimb1=muzzleclimb2;
			muzzleclimb2=muzzleclimb3;
			muzzleclimb3=muzzleclimb4;
			muzzleclimb4=(0,0);
		}


		//terminal velocity
		if(vel.z<-64)vel.z+=getgravity()*1.1;


		//"falling" damage
		double fallvel=teleported?0:(lastvel-vel).length();
		double heightmultsquared=heightmult*heightmult;


		//specific to hitting the ground at too high a speed
		double vdvxy=vel.xy dot vel.xy;
		if(
			vdvxy>150*strength
			&&!vel.z
			&&lastvel.z<-1000*strength/vdvxy
		){
			int frollamt=int(vdvxy*0.02);
			A_FaceMovementDirection();
			ForwardRoll(frollamt,FROLL_FORCE|FROLL_ADD);
			A_StartSound("weapons/smack",CHAN_BODY,CHANF_OVERLAP,volume:min(1.,abs(fallvel)*0.04));
			damagemobj(self,self,random(-3,(frollamt>>1)),"falling");
		}else if(
			player.onground
			&&lastvel.z
			&&!vel.z
			&&(vel.x||vel.y)
		)vel.xy-=vel.xy.unit()*abs(lastvel.z)*0.1;


		//don't bump against the sky
		if(
			lastvel.z>BUMPTHRESHOLD
			&&vel.z<=0
			&&(cursector.gettexture(cursector.ceiling)==skyflatnum)
			&&checkmove(pos.xy+lastvel.xy)
		){
			fallvel=0;
		}


		//count less if not actually blocked
		if(
			fallvel>BUMPTHRESHOLD-1
			&&abs(lastvel.z-vel.z)<4
			&&checkmove(pos.xy+lastvel.xy)
		)fallvel*=0.5;



		if(fallvel>BUMPTHRESHOLD-1){
			//check collision with shootables
			double zbak=pos.z;
			addz(lastvel.z);
			blockingmobj=null;
			if(
				!checkmove(pos.xy+lastvel.xy,PCM_NOLINES)
				&&blockingmobj
			){
				let bmob=blockingmobj;
				if(
					!bmob.bdontthrust
					&&bmob.mass>0
					&&bmob.mass<1000
				){
					bmob.A_StartSound("weapons/smack",CHAN_BODY,CHANF_OVERLAP,
						volume:min(1.,0.05*fallvel)
					);
					vector3 addmobvel=lastvel*90*heightmultsquared/bmob.mass;
					bmob.vel+=addmobvel;
					vel+=lastvel*0.05*heightmultsquared;
					if(fallvel>HURTTHRESHOLD){
						if(hdmobbase(bmob))hdmobbase(bmob).stunned+=int(addmobvel.length());
						bmob.damagemobj(self,self,int(fallvel*frandom(1,8)),"bashing");
					}else{
						//alert anyway
						HDMobAI.AcquireTarget(bmob,self);
					}
				}
			}
			setz(zbak);
		}


		if(fallvel>BUMPTHRESHOLD){
			if(barehanded)fallvel-=2;
			if(fallvel>HURTTHRESHOLD*(0.6+0.4*strength)){
				A_StartSound("weapons/smack",CHAN_BODY,CHANF_OVERLAP,volume:min(1.,0.05*fallvel));
				if(
					frandom(1,fallvel)>BUMPTHRESHOLD
					||(
						hdweapon(player.readyweapon)
						&&hdweapon(player.readyweapon).bweaponbusy
					)
				)Disarm(self);

				int fdmg=int(fallvel*fallvel*0.1*frandom(0.6,heightmultsquared));

				double fallrollratio=0.3*player.crouchfactor;
				if(
					fm>0
					&&!sm
				){
					if(barehanded)fallrollratio*=0.8;
				}

				if(
					fatigue<50
					&&stunned<60
					&&lastvel.z<-HURTTHRESHOLD
					&&max(abs(vel.x),abs(vel.y))>abs(lastvel.z)*fallrollratio
				){
					ForwardRoll(int(max(fallroll+fallvel,fallroll)));
					A_FaceMovementDirection();
					fdmg=(fdmg<<1)/7;
				}

				if(blockingline){
					if(
						doordestroyer.CheckDirtyWindowBreak(blockingline,mass*fallvel*0.0001,(pos.xy,pos.z+height*0.5))
					)vel+=lastvel*0.2;
				}

				damagemobj(self,self,fdmg,"falling");
				beatmax-=(fdmg>>3);
			}
		}
		if(stunned>0){
			int maxstun=int(TICRATE*120*strength);
			if(stunned>maxstun){
				A_Incapacitated(0,stunned);
				stunned=maxstun;
			}
			if(stunned>1&&stunned<strength*10)stunned-=2;
			else stunned--;
		}


		//more landing effects so you don't just... stop... like that
		if(
			!vel.z
			&&lastvel.z<-getgravity()
		){
			A_StartSound(landsound,CHAN_BODY,CHANF_OVERLAP,volume:min(1,abs(lastvel.z)*0.05));
			player.crouchfactor=min(player.crouchfactor,max(0.5,1.+lastvel.z*0.02));
			int lvlz=int(min(lastvel.z,0));
			stunned-=lvlz;
			if(!cursector.planemoving(sector.floor))vel.z-=lastvel.z*0.1;
			if(
				vel.z>1
				&&frame==4
			)PlayRunning();
		}


		//see if player is intentionally walking, running or sprinting
		//-1 = walk, 0 = run, 1 = sprint
		if(input & BT_SPEED)runwalksprint=1;
		else if(6400<max(abs(fm),abs(sm)))runwalksprint=0;
		else runwalksprint=-1;

		//check if hands free
		barehanded=(
			hdweapon(player.readyweapon)
			&&hdweapon(player.readyweapon).bdontnull
		);

		//reduce stepheight if crouched
		double crouchedheightmult=heightmult*player.crouchfactor;
		maxstepheight=default.maxstepheight*crouchedheightmult;

		if(heightmult)friction=0.985+0.03*heightmult;


		//get angle for checking high floors
		double checkangle;
		if(!vel.y&&!vel.x)checkangle=angle;else checkangle=atan2(vel.y,vel.x);

		//conditions for forcing walk
		if(
			stunned
			||jumptimer>0
			||health<25
			||fatigue>HDCONST_WALKFATIGUE
			||LineTrace(
				checkangle,26,0,
				TRF_THRUACTORS,
				offsetz:15
			)
			||(
				runwalksprint<1
				&&(fm||sm)
				&&floorz>=pos.z
				&&floorz-getzat(fm*0.004,sm*0.004)>16
			)
		){
			mustwalk=true;
			runwalksprint=-1;
		}else mustwalk=false;

		//conditions for allowing sprint
		if(
			!mustwalk
			&&barehanded
			&&fatigue<HDCONST_SPRINTFATIGUE
			&&!LineTrace(
				checkangle,56,0,
				TRF_THRUACTORS,
				offsetz:10
			)
		)cansprint=true;else cansprint=false;


		//encumbrance
		UpdateEncumbrance();
		double targetviewbob=VB_MAX*0.4;
		if(overloaded>1.){
			if(maxspeed<0.3){
				targetviewbob=VB_MAX;
				mustwalk=true;
				cansprint=false;
			}else if(maxspeed<0.4){
				targetviewbob=(VB_MAX*0.82);
				cansprint=false;
			}else if(maxspeed<1.){
				targetviewbob=(VB_MAX*0.65);
				cansprint=false;
			}else if(overloaded<1.2){
				targetviewbob=(VB_MAX*0.5);
			}
		}
		if(viewbob>targetviewbob)viewbob=max(viewbob-0.1,targetviewbob);
		else viewbob=min(viewbob+0.1,targetviewbob);

		//apply all movement speed modifiers
		speed=1.-overloaded*0.02-min(0.9,abs(lastvel.z-vel.z)*0.2);
		//walk
		if(mustwalk||cmdleanmove||runwalksprint<0)speed=min(speed,0.36);
		else if(cansprint && runwalksprint>0){
			//sprint
			if(!sm && fm>0){
				speed=2.;
				viewbob=max(viewbob,(VB_MAX*0.8));
			}else speed=1.4;
		}
		//cap speed depending on weapon status
		if(weaponbusy)speed=min(speed,0.6);
		else if(
			//weapons so bulky they get in the way physically
			//as a rule of thumb, anything that uses the "swinging" weapon hudbob
			hdweapon(player.readyweapon)
			&&hdweapon(player.readyweapon).bhinderlegs
		)speed=min(speed,0.7);

		speed=min(speed,maxspeed)*crouchedheightmult;

		canmovelegs=(vel.x,vel.y)dot(vel.x,vel.y)<45*strength*heightmult;

		if(jumptimer>0)jumptimer--;


		//special hud bobbing
		bobvelmomentum=(reactiontime>0?bobvelmomentum:max(bobvelmomentum,min(
			(bobvelmomentum+0.2)*1.3,
			max(abs(fm),abs(sm))*0.0003)
		))*0.8;
		double bobvel=max(0,bobvelmomentum)*viewbob;
		let pr=weapon(player.readyweapon);
		if(player.onground&&bobvel&&pr){
			bobcounter+=5.3*pr.bobspeed*player.crouchfactor;
			if(bobvel<0.1&&(89<bobcounter<90||269<bobcounter<270))bobcounter=90;
			else if(bobcounter>360)bobcounter=0;
		}
		hudbob=(
			cos(bobcounter)*(sm?5.:2.)*(pr?pr.bobrangex:1.)/(player.crouchfactor?player.crouchfactor:1.),
			(sin(bobcounter*2)+1.)*6.*(pr?pr.bobrangey:1.)
		)*bobvel+hudbobrecoil1;
		hudbobrecoil1=hudbobrecoil1*0.2+hudbobrecoil2;
		hudbobrecoil2=hudbobrecoil3;
		hudbobrecoil3=hudbobrecoil4;
		hudbobrecoil4=(0,0);

		if(recoilfov!=1.)recoilfov=(recoilfov+1.)*0.5;


		//regular weapon bobbing
		//does nothing if called in PlayerThink
		let wp=hdweapon(pr);
		if(wp){
			if(!wp.bweaponbusy){
				double hdbbx=(hudbobrecoil1.x+hudbob.x)*0.3;
				double hdbby=max(0,(hudbobrecoil1.y+hudbob.y)*0.3);
				A_WeaponOffset(hdbbx,hdbby+WEAPONTOP,WOF_INTERPOLATE);
			}else if(
				player.getpsprite(PSP_WEAPON).y<WEAPONTOP
			){
				A_WeaponOffset(
					player.getpsprite(PSP_WEAPON).x,
					max(player.getpsprite(PSP_WEAPON).y,WEAPONTOP),
					WOF_INTERPOLATE
				);
				bobcounter=60;
			}
		}

		//lowering weapon for sprint/mantle/jump
		if(
			input&(
				BT_SPEED
				|BT_JUMP
			)
			||totallyblocked
		){
			if(
				!barehanded
				&&(player.WeaponState & WF_WEAPONSWITCHOK)
			){
				let lw=hdweapon(player.readyweapon);
				A_SetInventory("NulledWeapon",1);
				A_SetInventory("NullWeapon",1);
				A_SelectWeapon("NullWeapon");
				if(lw){
					lastweapon=lw;
					let nw=hdweapon(findinventory("NullWeapon"));
					nw.barrellength=lw.barrellength+0.1;
					nw.barrelwidth=lw.barrelwidth+0.1;
					nw.barreldepth=lw.barreldepth+0.1;
				}
			}
		}else if(
			player.readyweapon is "NullWeapon"
		){
			if(lastweapon&&lastweapon.owner==self)A_SelectWeapon(lastweapon.getclassname());
			else A_SelectWeapon("HDFist");
		}else if(player.readyweapon is "HDFist")lastweapon=null;

		//display crosshair
		if(
			input&(
				BT_RELOAD
				|BT_USER3
				|BT_USER4
				|BT_JUMP
			)
			||weaponbusy
			||abs(player.cmd.yaw)>16384
			||binvulnerable
		)nocrosshair=12;
		else nocrosshair--;



		UseButtonCheck(input);


		//hold zoom to get some info
		bool forceview=
			barehanded
			&&(input&BT_ZOOM)
			&&!(input&(BT_ATTACK|BT_ALTATTACK))
		;
		if(
			!incapacitated
			&&(
				forceview
				||!(time&(1|2|4))
			)
		){
			flinetracedata flt;
			LineTrace(
				angle,(input&BT_ZOOM)?HDCONST_ONEMETRE*300:HDCONST_ONEMETRE*50,pitch,
				flags:TRF_ALLACTORS,
				offsetz:viewheight,
				data:flt
			);
			let aaa=flt.hitactor;
			if(
				!!aaa
				&&!aaa.binvisible
				&&!aaa.bspecialfiredamage
				&&(
					!ishostile(aaa)
					||(
						!inpain
						&&(
							aaa.target!=self
							||aaa.health<1
							||(!aaa.bismonster&&!aaa.player)
						)
					)
				)
				&&(
					HDWeapon(aaa)
					||HDMobBase(aaa)
					||aaa.gettag()!=aaa.getclassname()
				)
			){
				let oaa=HDOperator(aaa);
				if(oaa)oaa.LookMessage(self);
				if(
					forceview
					&&flt.distance<128
				){
					viewstring=aaa.gettag();
					if(
						!oaa
						&&!aaa.player
						&&playerpawn(aaa)
					)viewstring=viewstring.makelower();
				}else viewstring="";
			}else viewstring="";
		}else viewstring="";


		UpdateNearbyFriends();


		//this must be at the end since it needs to overwrite a lot of what has just happened
		IncapacitatedCheck();

		//record old shit
		oldfm=fm;
		oldsm=sm;
		lastpitch=pitch;
		lastangle=angle;
		lastheight=height;

		oldinput=input;
	}
	const BUMPTHRESHOLD=4.;
	const HURTTHRESHOLD=8.;
}
