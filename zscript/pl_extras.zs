// ------------------------------------------------------------
// Additional player functions
// ------------------------------------------------------------
class PlayerAntenna:HDActor{
	default{
		radius 3;
		height 2;
	}
}
extend class HDPlayerPawn{
	actor antenna;
	void A_MoveAntenna(vector3 newpos){
		if(!antenna)antenna=spawn("PlayerAntenna",newpos,ALLOW_REPLACE);
		else antenna.setorigin(newpos,false);
	}

	//check mantling
	//returns: -1 cannot mantle; 0 cannot mantle but on ground; 1 can mantle
	int MantleCheck(){
		if(incapacitated||incaptimer)return -1;
		bool onground=player.onground;
		int res=onground?0:-1;

		//check if there's a wall to kick off of
		if(
			res<0
			&&player.crouchfactor>0.8
		){
			double mshbk=maxstepheight;
			maxstepheight=8*heightmult;
			int cmflags=PCM_DROPOFF|PCM_NOACTORS;
			if(
				//go in the opposite direction of input
				(
					player.cmd.forwardmove<0
					&&!checkmove(
						pos.xy+angletovector(angle,8),
						cmflags
					)
				)||(
					player.cmd.forwardmove>0
					&&!checkmove(
						pos.xy-angletovector(angle,8),
						cmflags
					)
				)||(
					//moving right, check left
					player.cmd.sidemove>0
					&&!checkmove(
						pos.xy+angletovector(angle+90,6),
						cmflags
					)
				)||(
					//moving left, check right
					player.cmd.sidemove<0
					&&!checkmove(
						pos.xy+angletovector(angle-90,6),
						cmflags
					)
				)
			)res=0;
			maxstepheight=mshbk;
		}


		/*
			2021-10-24 After some consideration it appears there is no
			benefit in treating the initial boost upwards as anything
			other than a regular vertical leap. Notwithstanding some
			remnant code below, this line will simply abort in favour
			of a jump if the player is on the ground.
		*/
		if(
			onground
			&&jumptimer<1
			&&stunned<1
			&&fatigue<HDCONST_SPRINTFATIGUE
			&&player.crouchfactor==1.
		)return 0;


		//determine max height
		double mantlemax=36;  //basically just flop onto the thing and pull your legs up
		if(
			//can use arms, don't just flop
			barehanded
			&&health>12
			&&stunned<40
			&&fatigue<HDCONST_SPRINTFATIGUE
		)mantlemax=64;
		mantlemax*=heightmult*player.crouchfactor;
		double absmm=mantlemax+pos.z;

		//place the antenna
		A_MoveAntenna(pos+((cos(angle),sin(angle))*(radius+2),mantlemax));


		//check if blocked by geometry
		antenna.setz(absmm);
		antenna.FindFloorCeiling();
		double zat=antenna.floorz;


		//check if blocked by actor
		blockthingsiterator it=blockthingsiterator.create(antenna,1.);
		double apx=antenna.pos.x;double apy=antenna.pos.y;
		while(it.next()){
			actor itt=it.thing;
			if(
				itt
				&&itt.bsolid
				&&itt!=self
				&&cancollidewith(itt,false)
				&&!itt.bghost
				&&itt.mass>50
				&&(
					//I don't know why this iterator keeps fetching things FAR beyond the radius
					abs(itt.pos.x-apx)<itt.radius
					&&abs(itt.pos.y-apy)<itt.radius
				)
			){
				if(
					//climbing onto a mobile, living, potentially ticklish target
					itt.findstate("see")
					&&itt.health>0
				){
					itt.angle+=frandom(-10,10);
					muzzleclimb1.x+=frandom(-3,3);
					muzzleclimb1.y+=frandom(-1,1);

					itt.vel.xy+=(frandom(-0.3,0.3),frandom(-0.3,0.3))
						+angletovector(angle,frandom(0,0.3));

					bool friendly=itt.isfriend(self);

					if(
						!friendly
						||!itt.bnofear
						||!itt.bnopain
						||bspecialfiredamage
					){
						A_ChangeVelocity(
							frandom(-0.08,0.1)*(friendly?heightmult:heightmult*10),
							frandom(-0.1,0.1),frandom(-0.1,0.1),CVF_RELATIVE
						);
					}
					if(
						//resisting
						!friendly
						&&itt.bismonster  //players can choose to cooperate anyway
					){
						if(
							!itt.bfriendly
							||(multiplayer&&deathmatch&&!itt.isfriend(self))
						){
							A_Recoil(frandom(0,-1));
							if(itt.target!=self){
								itt.target=self;
								let hdmb=hdmobbase(itt);
								if(hdmb)hdmb.A_Vocalize(hdmb.painsound);
								else itt.A_StartSound(itt.painsound,CHAN_VOICE);
								if(itt.findstate("pain"))itt.setstatelabel("pain");
								else itt.setstatelabel("see");
							}
						}
						return res;
					}
				}
				double dz=itt.pos.z+itt.height;
				zat=max(dz,zat);
			}
		}

		if(
			zat>absmm
			||zat<pos.z+maxstepheight
		)return res;



		//thrust player upwards and forwards
		if(
			onground
			&&!(oldinput&BT_JUMP)
		){
			double thr=3.*strength;
			vel.z+=thr;
			fatigue+=random(1,2);
		}else{
			double pdif=((zat-pos.z)*strength*0.005);
			if(overloaded>1.)pdif/=overloaded;
			if(pdif>=0)vel.z+=pdif+getgravity();
		}
		return 1;
	}
	//and jump. don't separate from mantling.
	override void CheckJump(){}
	virtual void JumpCheck(double fm,double sm,bool forceslide=false){
		if(
			!forceslide
			&&player.cmd.buttons&BT_JUMP
		){
			int mcc=MantleCheck();
			if(
				player.crouchoffset
				&&mcc<1
			){
				//roll instead of stand
				double moveangle=absangle(angle,HDMath.AngleTo((0,0),vel.xy));
				double vxysq=(vel.x*vel.x+vel.y*vel.y);
				double mshbak=maxstepheight;
				maxstepheight=heightmult*HDCONST_ROLLMAXSTEPHEIGHT;
				if(
					!(hd_noslide.getint()&2)
					&&fm
					&&!sm
					&&player.crouchfactor<0.9

					//this is just copypasted from jump below
					&&!(oldinput & BT_JUMP)
					&&fatigue<HDCONST_SPRINTFATIGUE
					&&(
						!stunned
						||(
							//sliding forwards or backwards
							vxysq>4.
							&&(
								moveangle<6
								||moveangle<(180-6)
							)
						)
					)
					&&(
						fm<=0
						||checkmove(pos.xy+(cos(angle),sin(angle))*radius,PCM_DROPOFF)
					)
				){
					maxstepheight=mshbak;
					double rollamt=0;
					if(fm>0)rollamt=20+sqrt(vxysq);
					else rollamt=-20-sqrt(vxysq);
					if(rollamt){
						ForwardRoll(int(rollamt),FROLL_VOLUNTARY);
						A_ChangeVelocity(rollamt*0.2,0,player.onground?abs(rollamt)*0.1:0,CVF_RELATIVE);
						return;
					}
				}else maxstepheight=mshbak;

				// jump-to-stand is in CrouchCheck not here
			}
			else if(waterlevel>=2){
				vel.z=4*speed;
			}
			else if(bnogravity){
				vel.z=3;
			}
			else if(  // HERE COMES THE JUMP
				fatigue<HDCONST_SPRINTFATIGUE
				&&!mcc
				&&canmovelegs
				&&stunned<1
				&&jumptimer<=3
				&&!(oldinput&BT_JUMP)
			){
				double jumppower=max(0,maxspeed*strength+1);
				double jz=jumppower*0.5;

				vector2 jumpdir=(0,0);
				if(!sm){
					double ppp=pitch;
					if(fm){
						//forward
						jumpdir.x=cos(angle);
						jumpdir.y=sin(angle);
					}else{
						ppp=-90;
					}

					if(fm<0)jumpdir*=-1;
					else if(ppp<0){
						double pstr=jumppower*ppp*(-1./90.);
						jz+=pstr;
						jumppower-=pstr;
					}

				}else if(!fm){
					//side
					double rangle=angle+(sm>0?-90:90);
					jumpdir.x=cos(rangle);
					jumpdir.y=sin(rangle);
				}else{
					//diagonal
					double rangle=(sm>0?-45:45);
					if(fm<0)rangle*=3;
					rangle+=angle;
					jumpdir.x=cos(rangle);
					jumpdir.y=sin(rangle);
				}
				if(!checkmove(pos.xy+jumpdir*2,PCM_NOACTORS))jumpdir=(0,0);


				if(fm>0)jumppower*=(sm?1.2:1.4);
				vel.xy+=jumpdir*jumppower;
				vel.z+=jz;

				A_StartSound(
					landsound,CHAN_BODY,CHANF_OVERLAP,
					volume:min(1.,jumppower*0.04)
				);

				jumptimer+=18;
				fatigue+=3;

				//copied from sprint
				if(fatigue>=HDCONST_SPRINTFATIGUE){
					fatigue+=20;
					stunned+=400;
					A_StartSound(painsound,CHAN_VOICE);
				}

				if(bloodpressure<40)bloodpressure+=2;
			}
		}
		//slides, too!
		else if(
			forceslide||(
				(fm||sm)
				&&player.onground
				&&jumptimer<1
				&&player.crouchdir<0
				&&player.crouchfactor>0.5
				&&(
					runwalksprint>0
					||!(hd_noslide.getint()&1)
				)
			)
		){
			double mm=(strength*0.3+1.)*(lastheight-height)*(player.crouchfactor-0.5);
			double fmm=fm>0?mm:fm<0?-mm*0.6:0;
			double smm=sm>0?-mm:sm<0?mm:0;
			A_ChangeVelocity(fmm,smm,-0.6,CVF_RELATIVE);

			fatigue+=2;
			bloodpressure=max(bloodpressure,20);

			int stmod=int(strength*6.);
			stunned+=15-(stmod>>1);
			jumptimer+=35-stmod;

			smm*=-frandom(0.4,0.7);

			double slidemult=1.;
			let hdw=HDWeapon(player.readyweapon);
			if(hdw)slidemult=max(1.,0.1*hdw.gunmass());
			if(fmm<0){
				A_MuzzleClimb(
					(smm*1.2,-1.8)*slidemult,
					(smm,-1.3)*slidemult,
					(smm,-0.7)*slidemult,
					(smm*0.8,-0.3)*slidemult
				);
				if(slidemult>1.7)totallyblocked=true;
			}else if(fmm>0){
				A_MuzzleClimb(
					(smm*1.2,2.2)*slidemult,
					(smm,1.3)*slidemult,
					(smm,0.7)*slidemult,
					(smm*0.8,0.3)*slidemult
				);
				totallyblocked=true;
			}else{
				A_MuzzleClimb(
					(smm*0.6,-0.7)*slidemult,
					(smm,-0.3)*slidemult,
					(smm,-0.1)*slidemult,
					(smm*0.3,-0.07)*slidemult
				);
				if(slidemult>1.4)totallyblocked=true;
			}
		}
	}

	enum ForwardRollFlags{
		FROLL_ADD=1,
		FROLL_FORCE=2,
		FROLL_VOLUNTARY=4,
	}
	void ForwardRoll(int amt,int flags=0){
		if(
			!amt
			||incapacitated
			||health<1
			||stunned>TICRATE*5
			||(
				flags&FROLL_VOLUNTARY
				&&(
					fallroll
					||realpitch>90
					||realpitch<-90
					||fatigue>=HDCONST_SPRINTFATIGUE
					||stunned>40
				)
			)
		)return;

		//if voluntary, check if there's space in the direction being rolled.
		if(
			flags&FROLL_VOLUNTARY
		){
			vector2 checkpos=pos.xy+((cos(angle),sin(angle))*(amt<0?-10:10));
			if(!checkmove(checkpos))return;
		}

		if(amt>0){
			if(!(flags&FROLL_FORCE)&&fallroll<0)return;
			if(flags&FROLL_ADD)fallroll+=amt;
			else fallroll=max(fallroll,amt);
		}else{
			if(!(flags&FROLL_FORCE)&&fallroll>0)return;
			if(flags&FROLL_ADD)fallroll+=amt;
			else fallroll=min(fallroll,amt);
		}
		realpitch=pitch;
	}


	//all use button stuff other than normal using should go here
	virtual void UseButtonCheck(int input){
		if(!(input&BT_USE)){
			bpickup=false;
			return;
		}
		if(oldinput&BT_ATTACK)hasgrabbed=true;
		else if(!(oldinput&BT_USE))hasgrabbed=false;

        PickupGrabber(incapacitated?2:-1);

		//check here because we still need the above pickup checks when incap'd
		if(incapacitated)return;

		//door kicking
		if(
			input&BT_SPEED
			&&input&BT_ZOOM
			&&!jumptimer
			&&player.crouchfactor>0.8
			&&linetrace(angle,42,pitch,flags:TRF_THRUACTORS,offsetz:height*0.4)
		){
			hasgrabbed=true;
			jumptimer=20+(unstablewoundcount>>1);
			stunned+=25;
			double kickback=strength;
			
			flinetracedata kickline;
			bool kicky=linetrace(
				angle,height*0.5,pitch,
				TRF_NOSKY,
				offsetz:height*0.77,
				data:kickline
			);

			bool db=doordestroyer.destroydoor(self,frandom(32,72)*strength,frandom(0,frandom(1,16)*strength),ofsz:24);
			if(!random(0,db?7:3)){
				jumptimer+=20;
				damagemobj(self,self,random(1,5),"Bashing");
				stunned+=70;
				kickback*=frandom(1,2);
				A_MuzzleClimb((frandom(-1,1),4),(frandom(-1,1),-1),(frandom(-1,1),-1),(frandom(-1,1),-1));
			}
			if(!random(0,db?3:6))woundcount++;
			A_MuzzleClimb((0,-1),(0,-1),(0,-1),(0,-1));
			A_ChangeVelocity(-kickback,0,0,CVF_RELATIVE);
			A_StartSound("*fist",CHAN_BODY,CHANF_OVERLAP);
			LineAttack(angle,height*0.5,pitch,0,"none",
				strength>12.?"BulletPuffBig":"BulletPuffMedium",
				flags:LAF_OVERRIDEZ,
				offsetz:height*0.3
			);
		}


		bpickup=!hasgrabbed;

		//corpse kicking
		if(
			!jumptimer
			&&player.onground
			&&player.crouchfactor>0.7
			&&beatmax>10
		){
			bool kicked=false;
			actor k=spawn("kickchecker",pos,ALLOW_REPLACE);
			k.angle=angle;k.target=self;
			vector2 kv=AngleToVector(angle,5);
			for(int i=7;i;i--){
				if(!k.TryMove(k.pos.xy+kv,true) && k.blockingmobj){
					hasgrabbed=true;
					let kbmo=k.blockingmobj;
					double kbmolowerby=pos.z-kbmo.pos.z;
					if(
						kbmolowerby>4
						||kbmolowerby<-16
					)continue;
					if(
						kbmo.bcorpse
						||kbmo is "HDFragGrenade"
						||kbmo is "HDFragGrenadeRoller"
					){
						if(!(oldinput&BT_USE)){
							double forc=30*strength;
							jumptimer=20+(unstablewoundcount>>1);
							kbmo.vel+=(kv.x,kv.y,2.)*forc/kbmo.mass;
							kbmo.A_StartSound("misc/punch",CHAN_BODY,CHANF_OVERLAP);
							HDPlayerPawn.CheckStrip(kbmo,kbmo);
							kicked=true;
						}
					}else if(
						kbmo.health>0
						&&ishostile(kbmo)
					){
						jumptimer=17+(unstablewoundcount>>1);
						kicked=true;
						kick(kbmo,k);
					}else{
						double forc=0.4*strength;
						jumptimer=20+unstablewoundcount*3/5;
						vel-=(kv.x,kv.y,4)*forc/heightmult;
						kbmo.A_StartSound("misc/punch",CHAN_BODY,CHANF_OVERLAP);
						kicked=true;
					}
					break;
				}
			}
			if(kicked){
				fatigue++;bloodpressure++;stunned+=2;
			}
			if(k)k.destroy();
		}
	}

	void kick(actor kickee,actor kicking){
		kickee.A_StartSound("weapons/smack",CHAN_BODY,CHANF_OVERLAP);

		vector3 approachvel=
			(kickee.pos-pos)
			-((kickee.pos+kickee.vel)-(pos+vel))
		;

		int dmg=kickee.damagemobj(kicking,self,
			int((approachvel dot approachvel)*0.01)
			+int(frandom(10,20)*strength),
			"bashing"
		);
		vector3 kickdir=(kickee.pos-pos).unit();
		vel-=kickdir;

		if(!kickee)return;
		if(random(0,4))hdmobbase.forcepain(kickee);
		if(
			ishostile(kickee)
			&&(!kickee.target||!kickee.checksight(kickee.target))
		){
			if(kickee.target)kickee.lastenemy=kickee.target;
			kickee.target=self;
		}
		if(!kickee.bdontthrust)kickee.vel=kickdir*strength*mass/max(mass*0.3,kickee.mass);

		if(
			kickee.health>0
			&&hdmobbase.inpainablesequence(kickee)
			&&kickee.findstate("falldown")
			&&frandom(0,mass/kickee.mass)*dmg>1.6
		){
			kickee.setstatelabel("falldown");
		}
	}
}



extend class HDHandlers{
	static void FindRange(hdplayerpawn ppp){
		flinetracedata frt;
		ppp.linetrace(
			ppp.angle,65536,ppp.pitch,flags:TRF_NOSKY,
			offsetz:ppp.height*0.89,
			data:frt
		);
		double c=frt.distance;
		double b=c/HDCONST_ONEMETRE;
		ppp.A_Log(string.format("\cd[\cuRF\cd]\cj \cf%.2f\cj metre%s",b,b==1?"":"s"),true);
		if(hd_debug)ppp.A_Log(string.format("("..(ppp.player?ppp.player.getusername():"something").." measured %.2f DU%s)",c,c==1?"":"s"),true);

		if(
			ppp.player
			&&ppp.player.cmd.buttons&BT_USE
		){
			let hdw=HDWeapon(ppp.player.readyweapon);
			if(hdw)hdw.airburst=int(b*100);
		}
	}
	void Taunt(hdplayerpawn ppp){
		ppp.A_StartSound(ppp.tauntsound,CHAN_VOICE);
		ppp.bspawnsoundsource=true;
		let dtt=new("DelayedTaunter");
		dtt.target=ppp;
		dtt.timer=18;
		if(ppp.findinventory("HDBlurSphere"))
			HDBlursphere(ppp.findinventory("HDBlurSphere")).intensity=-200;
	}
	void ClearWeaponSpecial(hdplayerpawn ppp){
		if(!ppp.player)return;
		let www=hdweapon(ppp.player.readyweapon);
		if(www)www.special=0;
	}
	void ForwardRoll(hdplayerpawn ppp,int amt){
		if(ppp.player){
			int rollamt=clamp(amt,-20,20);
			ppp.ForwardRoll(rollamt,ppp.FROLL_VOLUNTARY);
			if(ppp.player.onground)
				ppp.A_ChangeVelocity(0.2*rollamt,0,0.1*abs(rollamt),CVF_RELATIVE);
		}
	}
}
class DelayedTaunter:Thinker{
	actor target;
	int timer;
	override void Tick(){
		timer--;
		if(timer<0){
			target.bspawnsoundsource=true;
			HDMobAI.HDNoiseAlert(target);
			destroy();
		}
	}
}


extend class HDPlayerPawn{
	array<actor> nearbyfriends;
	void UpdateNearbyFriends(){
		if(level.time&(1|2|4|8|16|32))return;
		nearbyfriends.clear();
		blockthingsiterator itt=blockthingsiterator.create(self,256);
		while(itt.Next()){
			actor it=itt.thing;
			if(
				it
				&&it.bismonster
				&&it.health>0
				&&isfriend(it)
			)if(
				level.time&(64)
			)nearbyfriends.insert(0,it);
			else nearbyfriends.push(it);
		}
	}
}
