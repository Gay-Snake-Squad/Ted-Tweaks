// ------------------------------------------------------------
// Pain Lord/Pain Bringer common
// ------------------------------------------------------------
class PainMonster:HDMobBase{
	default{
		meleesound "baron/melee";
		bloodcolor "44 99 22";
		+hdmobbase.biped
		species "BaronOfHell";
	}
	override void postbeginplay(){
		super.postbeginplay();
		bsmallhead=bplayingid;
		if(
			!bplayingid
			&&getclassname()!="PainLord"  //2022-05-28 FD's sprite still uses green blood in death anim
		){
			for(int i=0;i<MAXPLAYERS;i++){
				let hdp=hdplayerpawn(players[i].mo);
				if(hdp)CopyBloodColor(hdp);
			}
		}
	}
	override double bulletresistance(double hitangle){
		return super.bulletresistance(hitangle);
	}
}
// ------------------------------------------------------------
// Pain Lord
// ------------------------------------------------------------
class PainLord:PainMonster replaces BaronofHell{
	default{
		height 64;
		radius 17;
		mass 1000;
		+bossdeath
		seesound "baron/sight";
		painsound "baron/pain";
		deathsound "baron/death";
		activesound "baron/active";
		obituary "$ob_baron";
		hitobituary "$ob_baronhit";
		tag "$CC_BARON";
		+e1m8boss
		+missilemore +dontharmspecies
		maxtargetrange 65536;
		damagefactor "hot",0.8;
		damagefactor "cold",0.7;
		damagefactor "slashing",0.86;
		damagefactor "piercing",0.95;
		damagefactor "balefire",0.3;
		meleedamage 12;
		meleerange 58;
		health BE_HPMAX;
		speed 6;
		painchance 4;
		hdmobbase.shields 2000;
	}
	enum BaronStats{
		BE_HPMAX=1000,
		BE_OKAY=BE_HPMAX*7/10,
		BE_BAD=BE_HPMAX*3/10,
	}
	override double bulletshell(vector3 hitpos,double hitangle){
		return frandom(3,12);
	}
	override double bulletresistance(double hitangle){
		return max(0,frandom(0.8,1.)-hitangle*0.008);
	}
	override void postbeginplay(){
		super.postbeginplay();
		resize(0.95,1.05);
	}
	override void tick(){
		super.tick();
		if(!isfrozen()&&firefatigue>0)firefatigue-=2;
	}
	states{
	spawn:
		BOSS AA 8 A_HDLook();
		BOSS A 1 A_SetTics(random(1,16));
		BOSS BB 8 A_HDLook();
		BOSS B 1 A_SetTics(random(1,16));
		BOSS CC 8 A_HDLook();
		BOSS C 1 A_SetTics(random(1,16));
		BOSS DD 8 A_HDLook();
		BOSS D 1 A_SetTics(random(1,16));
		TNT1 A 0 A_Jump(216,"spawn");
		TNT1 A 0 A_StartSound("baron/active",CHAN_VOICE);
		loop;
	see:
		BOSS ABCD 6 A_HDChase();
		TNT1 A 0 A_JumpIfTargetInLOS("see");
		goto roam;
	roam:
		BOSS A 0 A_JumpIfTargetInLOS("missile");
		BOSS A 0 A_ShoutAlert(0.3,SAF_SILENT);
		BOSS ABCD 8 A_HDWander(CHF_LOOK);
		loop;
	missile:
		BOSS ABCD 3 A_TurnToAim(30,32);
		loop;
	shoot:
		BOSS A 0{
			A_ShoutAlert(0.8,SAF_SILENT);
			if(
				lasttargetdist<420
				||!random(0,5)
			)return;
			if(
				health>BE_OKAY
				||health<BE_BAD
			)setstatelabel("MissileAll");
			else if(!random(0,1))setstatelabel("MissileSkull");
			else setstatelabel("MissileAura");
		}
		goto MissileSweep;
	MissileSkull:
		BOSS H 10;
		BOSS H 2 A_LeadTarget(lasttargetdist*0.10);
		BOSS H 12 bright A_SpawnProjectile("BelphBall",34,0,0,2,pitch);
		BOSS H 18;
		goto MissileSweep;
	MissileAll:
		BOSS H 12;
		BOSS H 6 A_LeadTarget(lasttargetdist*0.12);
		BOSS H 0 bright A_SpawnProjectile("BaleBall",38,0,2,0,0);
		BOSS H 0 bright A_SpawnProjectile("BaleBall",38,0,-2,0,0);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",46,0,5,2,0);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",46,0,-5,2,0);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",56,0,7,2,4);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",56,0,-7,2,4);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",66,0,12,2,7);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",66,0,-12,2,7);
		BOSS H 12 bright A_SpawnProjectile("BelphBall",28,0,0,2,pitch);
		---- A 0 setstatelabel("see");
	MissileAura:
		BOSS H 10;
		BOSS H 6 A_LeadTarget(lasttargetdist*0.12);
		BOSS H 0 bright A_SpawnProjectile("BaleBall",38,0,2,0,0);
		BOSS H 6 bright A_SpawnProjectile("BaleBall",38,0,-2,0,0);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",46,0,9,2,0);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",46,0,-9,2,0);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",56,0,17,2,4);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",56,0,-17,2,4);
		BOSS H 0 bright A_SpawnProjectile("MiniBBall",66,0,24,2,7);
		BOSS H 6 bright A_SpawnProjectile("MiniBBall",66,0,-24,2,7);
		BOSS H 12;
		---- A 0 setstatelabel("see");
	MissileSweep:
		BOSS F 4;
		BOSS E 6 A_LeadTarget(lasttargetdist*0.14);
		BOSS E 2 A_SpawnProjectile("MiniBBall",56,6,-6,CMF_AIMDIRECTION,pitch);
		BOSS F 2 A_SpawnProjectile("MiniBBall",46,4,-3,CMF_AIMDIRECTION,pitch);
		BOSS F 2 A_SpawnProjectile("MiniBBall",38,0,-1,CMF_AIMDIRECTION,pitch);
		BOSS G 2 A_SpawnProjectile("MiniBBall",32,0,1,CMF_AIMDIRECTION,pitch);
		BOSS G 2 A_SpawnProjectile("MiniBBall",32,0,3,CMF_AIMDIRECTION,pitch);
		BOSS G 2 A_SpawnProjectile("MiniBBall",32,0,6,CMF_AIMDIRECTION,pitch);
		BOSS G 6;
		BOSS E 2 A_Jump(194,"see");
		loop;
	pain:
		BOSS H 6 A_Pain();
		BOSS H 3 A_Jump(116,"see","MissileSkull");
	melee:
		BOSS E 6 A_FaceTarget();
		BOSS F 2;
		BOSS G 6 A_CustomMeleeAttack(random(40,120),"baron/melee","","claws",true);
		BOSS F 5 A_JumpIf(target&&distance3d(target)>84,"missilesweep");
		---- A 0 setstatelabel("see");
	death.telefrag:
		TNT1 A 0 spawn("Telefog",pos,ALLOW_REPLACE);
		TNT1 A 0 A_NoBlocking();
		TNT1 AAAAA 0 A_SpawnItemEx("BFGNecroShard",
			frandom(-4,4),frandom(-4,4),frandom(6,24),
			frandom(1,6),0,frandom(1,3),
			frandom(0,360),SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS|SXF_SETMASTER
		);
		TNT1 A 100;
		TNT1 A 0 A_BossDeath();
		stop;
	death:
		---- A 0{
			bodydamage+=666*5;
			A_QuakeEx(1,1,2,64,0,512,flags:QF_SCALEDOWN,falloff:32);
		}
		BOSS I 2 A_SpawnItemEx("BFGNecroShard",0,0,20,10,0,8,45,SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		BOSS I 2 A_SpawnItemEx("BFGNecroShard",0,0,35,10,0,8,135,SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		BOSS I 2 A_SpawnItemEx("BFGNecroShard",0,0,50,10,0,8,225,SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		BOSS I 2 A_SpawnItemEx("BFGNecroShard",0,0,65,10,0,8,315,SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		BOSS J 8 A_Vocalize(default.deathsound);
		BOSS KLMN 8;
		BOSS OOOOO 6;
		BOSS O -1 A_BossDeath();
		stop;
	death.maxhpdrain:
		BOSS J 5 A_StartSound("misc/gibbed",CHAN_BODY);
		BOSS KLMN 5;
		BOSS O -1;
	raise:
		BOSS ONMLKJI 5;
		BOSS H 8;
		BOSS AB 6 A_HDWander(CHF_LOOK);
		#### A 0 A_Jump(256,"see");
	}
}
class BelphBall:FastProjectile{
	default{
		+forcexybillboard +seekermissile +hittracer
		damagetype "hot";
		decal "bigscorch";
		renderstyle "add";
		alpha 0.05;
		radius 4;
		height 4;
		speed 2;
		damage 8;
		seesound "baron/bigballf";
		deathsound "baron/bigballx";
	}
	override void postbeginplay(){
		super.postbeginplay();
		let hdmb=hdmobbase(target);
		if(hdmb)hdmb.firefatigue+=int(HDCONST_MAXFIREFATIGUE*0.7);
	}
	states{
	spawn:
		MISL DCCBB 1 bright A_FadeIn(0.2);
		BAL1 A 0 bright A_ScaleVelocity(32);
	see:
		BAL1 AB 1{
			vector3 vv=vel*0.3;
			vector3 vvv=vv*-0.1;
			vector3 vvvv=vel.unit();
			double vl=vel.length();
			for(int i=0;i<4;i++)A_SpawnParticle(
				"ef ff db",SPF_FULLBRIGHT,
				random(10,20),frandom(30,40),
				0,
				vvvv.x*frandom(0,-vl),vvvv.y*frandom(0,-vl),vvvv.z*frandom(0,-vl)+4,
				vv.x+frandom(-1,1),vv.y*0.3+frandom(-1,1),vv.z*0.3+frandom(0.9,1.3),
				vvv.x,vvv.y,vvv.z+0.01
			);
		}
		loop;
	death:
		MISL BBBBBB 0 A_SpawnItemEx("HDSmoke",0,0,random(-2,4),frandom(-2,2),frandom(-2,2),random(3,5),0,SXF_NOCHECKPOSITION);
		MISL B 1 bright A_Quake(3,28,0,128);
		MISL B 1 bright A_Explode(56,96,1);
		MISL BBBBBBBBBBB 0 A_SpawnItemEx("BigWallChunk",0,0,random(-4,4),random(-10,10),random(-10,10),random(-2,10),random(0,360),SXF_NOCHECKPOSITION);
		MISL CCDD 1 bright A_FadeOut(0.2);
		TNT1 AAAAA random(2,3) A_SpawnItemEx("HDSmoke",0,0,random(-2,4),frandom(-2,2),frandom(-2,2),random(3,5),0,SXF_NOCHECKPOSITION);
		stop;
	}
}
class MiniBBallTail:HDActor{
	default{
		+nointeraction
		+forcexybillboard
		renderstyle "add";
		alpha 0.6;
		scale 0.7;
	}
	states{
	spawn:
		BAL7 E 2 bright A_FadeOut(0.2);
		TNT1 A 0 A_StartSound("baron/ballhum",volume:0.4,attenuation:6.);
		loop;
	}
}
class MiniBBall:HDActor{
	default{
		+forcexybillboard
		projectile;
		+seekermissile
		damagetype "balefire";
		renderstyle "add";
		decal "gooscorch";
		alpha 0.8;
		scale 0.6;
		radius 4;
		height 6;
		speed 16;
		damage 6;
		seesound "baron/attack";
		deathsound "baron/shotx";
	}
	int user_counter;
	override void postbeginplay(){
		super.postbeginplay();
		let hdmb=hdmobbase(target);
		if(hdmb)hdmb.firefatigue+=int(HDCONST_MAXFIREFATIGUE*0.1);
	}
	states{
	spawn:
		BAL7 EDC 1 bright;
		BAL7 ABABA 2 bright;
		BAL7 BAB 3 bright;
	spawn2:
		BAL7 A 2 bright A_SeekerMissile(5,10);
		BAL7 B 2 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
		BAL7 A 2 bright A_SeekerMissile(5,9);
		BAL7 B 2 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
		BAL7 A 2 bright A_SeekerMissile(4,8);
		BAL7 B 2 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
		BAL7 A 2 bright A_SeekerMissile(3,6);
		BAL7 B 2 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
	spawn3:
		TNT1 A 0 A_JumpIf(user_counter>4,"spawn4");
		TNT1 A 0 {user_counter++;}
		BAL7 A 3 bright A_SeekerMissile(1,1);
		BAL7 B 3 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
		loop;
	spawn4:
		BAL7 A 3 bright A_SpawnItemEx("MiniBBallTail",-3,0,3,3,0,random(1,2),0,161,0);
		TNT1 A 0 A_JumpIf(pos.z-floorz<10,2);
		BAL7 B 3 bright A_ChangeVelocity(frandom(-0.2,1),frandom(-1,1),frandom(-1,0.9),CVF_RELATIVE);
		loop;
		BAL7 B 3 bright A_ChangeVelocity(frandom(-0.2,1),frandom(-1,1),frandom(-0.6,1.9),CVF_RELATIVE);
		loop;
	death:
		BAL7 CDE 4 bright A_FadeOut(0.2);
		stop;
	}
}
class zbbt:hdfireballtail{
	default{
		translation 2;
		renderstyle "subtract";
		deathheight 0.9;
		gravity 0;
		scale 0.6;
	}
	override void tick(){
		super.tick();
		if(alpha==height)addz(6);
	}
	states{
	spawn:
		BAL7 CDE 2{
			roll+=10;
			scale.x*=randompick(-1,1);
		}loop;
	}
}
class BaleBall:hdfireball{
	default{
		missiletype "zbbt";
		damagetype "balefire";
		activesound "baron/ballhum";
		decal "gooscorch";
		gravity 0;
		speed 20;
		hdfireball.firefatigue int(HDCONST_MAXFIREFATIGUE*0.2);
	}
	actor lingerburner;
	override void ondestroy(){
		if(lingerburner)lingerburner.destroy();
		super.ondestroy();
	}
	states{
	spawn:
		BAL7 A 0 nodelay{
			actor bbl=spawn("BaronBallLight",pos,ALLOW_REPLACE);bbl.target=self;
		}
		BAL7 ABAB 3 A_FBTail();
	spawn2:
		BAL7 AB 3 A_FBFloat();
		loop;
	death:
		BAL7 A 0{
			vel.z+=0.5;
			if(!blockingmobj){
				tracer=null;
				setstatelabel("burn");
				lingerburner=spawn("BaleBallBurner",pos,ALLOW_REPLACE);
				lingerburner.target=target;lingerburner.master=self;
				return;
			}else if(
				target
				&&blockingmobj.health>0
				&&target.health>0
				&&blockingmobj.getspecies()==target.getspecies()
				&&!(blockingmobj.ishostile(target))
			)return;
			else if(tracer&&blockingmobj==tracer){
				vel.z=2;
				tracer.damagemobj(self,target,random(16,32),"balefire");
				alpha=1;scale*=1.2;
				setstatelabel("burn");
			}
		}
	splat:
		BAL7 CDE 4;
		stop;
	burn:
		BAL7 CDE 3{
			A_FadeOut(0.05);
			frame=random(2,4);roll=random(0,360);
			if(!tracer){
				addz(0.1);
				return;
			}
			if(tracer is "HDPlayerPawn"&&tracer.health<1&&HDPlayerPawn(tracer).playercorpse){
				tracer=HDPlayerPawn(tracer).playercorpse;
			}
			double trad=tracer.radius;double tht=tracer.height;
			setxyz(tracer.pos+(frandom(-trad,trad),frandom(-trad,trad),frandom(tht*0.5,tht)));
			if(alpha>0.3){
				tracer.damagemobj(self,target,random(1,3),"balefire");
			}else{
				A_Immolate(tracer,target,random(10,20));
				destroy();
			}
		}wait;
	}
}
class BaleBallBurner:PersistentDamager{
	default{
		height 12;radius 20;stamina 1;
		damagetype "balefire";
	}
}
class BaronBallLight:PointLight{
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=64;
		args[1]=196;
		args[2]=48;
		args[3]=0;
		args[4]=0;
	}
	override void tick(){
		if(!target){
			args[3]+=random(-10,1);
			if(args[3]<1)destroy();
		}else{
			setorigin(target.pos,true);
			if(target.bmissile)args[3]=random(32,40);
			else args[3]=random(48,64);
		}
	}
}