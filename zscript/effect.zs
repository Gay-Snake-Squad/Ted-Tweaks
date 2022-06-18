// ------------------------------------------------------------
//   Misc. effects
// ------------------------------------------------------------
//channel constants
enum HDSoundChannels{
	CHAN_WEAPONBODY=8,  //for weapon sounds that are not the gun firing
	CHAN_POCKETS=9,  //for pocket sounds in reloading, etc.
	CHAN_ARCZAP=69420,  //electrical zapping arc noises
	CHAN_DISTANT=4047,  //distant gunfire sounds
}
//debris actor: simplified physics, just bounce until dead and lie still, +noblockmap
//basically we just need to account for conveyors and platforms
class HDDebris:HDActor{
	bool stopped;
	double grav;
	double wdth;
	default{
		+noblockmap -solid -shootable +dontgib +forcexybillboard +notrigger +cannotpush
		height 2;radius 2;
		bouncesound "misc/casing2";bouncefactor 0.4;maxstepheight 2;
		+rollsprite;+rollcenter;
	}
	override void postbeginplay(){
		if(max(abs(pos.x),abs(pos.y),abs(pos.z))>=32768){destroy();return;}
		super.postbeginplay();
		stopped=false;
		grav=getgravity();
		if(bwallsprite)grav*=frandom(0.4,0.9);
		wdth=radius*1.8;
	}
	override void Tick(){
		if(isfrozen())return;
		if(bmovewithsector){
			actor.tick();
			if(bnointeraction)return;
			if(vel.xy==(0,0)&&floorz>=pos.z){
				setz(floorz);
				bnointeraction=true;
			}
			return;
		}
		double velxylength=vel.xy.length();
		int fracamount=int(max(1,velxylength/radius));
		vector3 frac=vel/fracamount;
		bool keeptrymove=true;
		for(int i=0;i<fracamount;i++){
			addz(frac.z,true);
			if(keeptrymove&&!trymove(pos.xy+frac.xy,true,true)){
				A_StartSound(bouncesound);
				if(blockingmobj){
					vel*=-bouncefactor;
				}else if(blockingline){
					vel*=bouncefactor;
					vel.xy=rotatevector(vel.xy,frandom(80,280));
				}
				keeptrymove=false;
			}
		}
		checkportaltransition();
		bool onfloor=floorz>=pos.z;
		//bounce off floor or ceiling
		if(
			onfloor
			||ceilingz<=pos.z //most debris actors are negligible height
		){
			if(onfloor)setz(floorz);
			A_StartSound(bouncesound);
			if(velxylength)vel.xy=rotatevector(vel.xy,frandom(-10,10)*(vel.z?1./vel.z:0.01))*bouncefactor;
			else vel.xy=(frandom(-0.01,0.01),frandom(-0.01,0.01));
			vel.z=onfloor?abs(vel.z*bouncefactor):-abs(vel.z*bouncefactor);
		}
		//apply gravity
		if(onfloor){
			if(velxylength<0.01){
				if(findstate("death"))setstatelabel("death");
				else{destroy();return;}
				brelativetofloor=true;
				bmovewithsector=true;
				if(vel.x||vel.y)vel.xy+=vel.xy.unit()*abs(vel.z);
			}else vel.xy*=0.99;
		}else vel.z-=grav;
		NextTic();
	}
}
//the wallchunk!
class WallChunk:HDDebris{
	default{
		+noteleport
		scale 0.16;bouncesound "none";
	}
	int flip;
	override void postbeginplay(){
		super.postbeginplay();
		scale.x*=randompick(-1,1)*frandom(0.6,1.3);
		scale.y*=frandom(0.6,1.3);
		bwallsprite=randompick(0,0,0,1); //+wallsprite crashes software
		roll=random(0,3)*90;
		flip=random(1,4);
		if(!random(0,9))A_StartSound("misc/wallchunks");
		frame=random(0,3);
		bouncefactor=frandom(0.1,0.3);
	}
	void A_Dust(){
		A_SetScale(-scale.x,scale.y);
		A_SetTics(flip);
		angle=angle+45*flip;
	}
	states{
	spawn:
		DUST # 1 nodelay A_Dust();
		wait;
		---- BCD 0;
	death:
		---- A 1 A_SetTics(random(10,20)<<3);
		stop;
	}
}
class WallChunker:HDActor{
	default{
		height 8;radius 12;
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(
			ceilingz-pos.z<height
			&&pos.z-floorz<2
			&&checkmove(pos.xy,PCM_NOACTORS)
		){
			destroy();
			return;
		}
		if(ceilingz-pos.z<12&&pos.z-floorz>12)chunkdir=-2;
		else chunkdir=5;
	}
	double chunkdir;
	states{
	spawn:
		TNT1 AAAAAAAAAAAAAAAAAAAAAA 0 A_SpawnItemEx("HugeWallChunk",0,0,4,frandom(6,12),0,frandom(-3,12)*chunkdir,frandom(0,360),SXF_NOCHECKPOSITION);
		TNT1 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 0 A_SpawnItemEx("BigWallChunk",0,0,4,frandom(7,18),0,frandom(-3,14)*chunkdir,frandom(0,360),SXF_NOCHECKPOSITION);
		TNT1 AA 0 A_SpawnItemEx ("HDSmoke",-1,0,1,frandom(-2,2),0,0,frandom(0,360),SXF_NOCHECKPOSITION);
		stop;
	}
}
//the other chunk!
class HDSmokeChunk:HDDebris{
	default{
		scale 0.2;
		damagetype "hot";
		obituary "%o was smoked and roasted.";
		bouncefactor 0.2;bouncesound "";
	}
	states{
	spawn:
		DUST A 0 nodelay{
			frame=random(0,3);
			scale*=randompick(-1,1);
			if(!random(0,4))brockettrail=true;
			if(!random(0,4))bgrenadetrail=true;
		}
	spawn2:
		---- A random(3,7){
			accuracy++;
			if(accuracy>=18)setstatelabel("death");
			A_StartSound("misc/firecrkl",CHAN_BODY,
				volume:0.2,pitch:frandom(0.8,1.2)
			);
		}
		loop;
		DUST ABCD 0;
	death:
		PUFF C 0{
			bnogravity=true;
			vel.z+=0.3;
			A_SetScale(randompick(-1,1)*frandom(0.4,0.6),frandom(0.4,0.6));
			A_SetRenderStyle(0.6,Style_Add);
		}
		PUFF CCCCCDDDD 1{
			scale*=1.1;
			A_FadeOut(0.05);
		}
		stop;
	}
}
//puffs for smoke, bulletpuffs, flames, etc.
class HDPuff:HDActor{
	double decel;double fade;double grow;int fadeafter;double minalpha;double startvelz;double grav;
	property decel:decel;
	property fade:fade;
	property grow:grow;
	property fadeafter:fadeafter;
	property minalpha:minalpha;
	property startvelz:startvelz;
	default{
		+puffgetsowner +hittracer
		+noblockmap -solid +cannotpush
		+nointeraction
		+rollsprite +rollcenter +forcexybillboard
		height 0;radius 0;renderstyle "translucent";gravity 0.1;
		hdpuff.decel 0.9;
		hdpuff.fade 0.98;
		hdpuff.fadeafter 10;
		hdpuff.grow 0.14;
		hdpuff.minalpha 0.1;
		hdpuff.startvelz 2.;
	}
	override void postbeginplay(){
		HDActor.postbeginplay();
		if(max(abs(pos.x),abs(pos.y),abs(pos.z))>=32768){destroy();return;}
		roll=random(0,3)*90;
		scale.x*=randompick(-1,1);
		grow*=scale.x;
		vel.z+=startvelz;
		grav=getgravity();
	}
	override void Tick(){
		if(isfrozen())return;
		alpha*=fade;
		if(alpha<minalpha){
			destroy();
			return;
		}
		scale.x+=grow;scale.y=scale.x;
		vel*=decel;
		vel.z-=grav;
		if(
			(vel.x||vel.y)
			&&!trymove(pos.xy+vel.xy,true)
		)vel.xy=(0,0);
		if(vel.z){
			if(
				(vel.z>0 && pos.z+8>ceilingz)||
				(vel.z<0 && pos.z<floorz)
			)vel.z=0;
			addz(vel.z);
		}
		if(pos.z>ceilingz)setz(ceilingz-8);
		else if(pos.z<floorz)setz(floorz);
		NextTic();
	}
    override void BeginPlay()
	{
		ChangeStatNum(STAT_USER);
		Super.BeginPlay();
	}

}
class HDBulletPuff:HDPuff{
	int scarechance;
	property scarechance:scarechance;
	default{
		stamina 5;missiletype "WallChunk";alpha 0.8;
		hdpuff.decel 0.7;
		hdpuff.fadeafter 0;
		hdpuff.fade 0.9;
		hdpuff.grow 0.1;
		hdpuff.minalpha 0.1;
		hdpuff.startvelz 4;
		gravity 0.1;
		hdbulletpuff.scarechance 5;
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(max(abs(pos.x),abs(pos.y),abs(pos.z))>=32768){destroy();return;}
		if(target&&(
			!!target.player
			||botbot(target)
		))scarechance>>=2;
		if(!random(0,scarechance))hdmobai.frighten(self,256);
		int stm=stamina;
		double vol=min(1.,0.1*stm);
		A_StartSound("misc/bullethit",CHAN_BODY,CHANF_OVERLAP,vol);
		A_ChangeVelocity(-0.4*cos(pitch),0,frandom(0.1,0.4)*-sin(pitch),CVF_RELATIVE);
		trymove(pos.xy+vel.xy,false);
		scale*=frandom(0.9,1.1);
		let gdfmt=getdefaultbytype((class<actor>)(missilename));
		for(int i=0;i<stamina;i++){
			A_SpawnParticle("gray",
				SPF_RELATIVE,70,frandom(4,20)*gdfmt.scale.x,0,
				frandom(-3,3),frandom(-3,3),frandom(0,4),
				frandom(-0.1,.8)*stm,frandom(-0.3,0.3)*stm,vel.z+frandom(0.1,0.3)*stm,
				frandom(-0.1,0.1),frandom(-0.1,0.1),-HDCONST_GRAVITY
			);
		}
	}
	void A_CheckSmokeSprite(){
		if(abs(scale.y)>3.){
			setstatelabel("toobig");
			scale*=0.3;
			grow*=0.3;
		}
	}
	states{
	spawn:
		TNT1 A 0 nodelay A_CheckSmokeSprite();
		PUFF CD 8;wait;
	toobig:
		RSMK AB 8;wait;
	}
}
class BulletPuffBig:HDBulletPuff{
	default{
		stamina 5;scale 0.6;
		hdbulletpuff.scarechance 5;
	}
}
class BulletPuffMedium:HDBulletPuff{
	default{
		stamina 4;scale 0.5;
		hdbulletpuff.scarechance 10;
	}
}
class BulletPuffSmall:HDBulletPuff{
	default{
		stamina 3;scale 0.4;missiletype "TinyWallChunk";
		hdbulletpuff.scarechance 20;
	}
}
class FragPuff:HDBulletPuff{
	default{
		stamina 1;scale 0.5;
		hdbulletpuff.scarechance 40;
	}
}
class PenePuff:HDBulletPuff{
	default{
		stamina 4;scale 0.6;
		hdbulletpuff.scarechance 4;
	}
	states{
	spawn:
		TNT1 A 0 nodelay A_CheckSmokeSprite();
		PUFF ABCD 2;wait;
	toobig:
		RSMK ABCD 2; wait;
	}
}
class HDSmoke:HDPuff{
	default{
		scale 1;gravity 0.05;alpha 0.7;
		hdpuff.fadeafter 3;
		hdpuff.decel 0.96;
		hdpuff.fade 0.96;
		hdpuff.grow 0.02;
		hdpuff.minalpha 0.005;
	}
	override void BeginPlay()
	{
		ChangeStatNum(STAT_USER + 2);
		Super.BeginPlay();
	}
	override void postbeginplay(){
		actor smm;
		int bcc=0;
		thinkeriterator bexpm=ThinkerIterator.create(GetClass(), STAT_USER + 2);
		actor osm;
		while(smm=actor(bexpm.next())){
			if(
				abs(smm.pos.x-pos.x)<128
				&&abs(smm.pos.y-pos.y)<128
			){
				if(!bcc)osm=smm;
				bcc++;
			}
			if(
				bcc>20
				&&!!osm
			){
				osm.destroy();
				break;
			}
		}
		super.postbeginplay();
	}
	states{
	spawn:
		RSMK A random(3,5);RSMK A 0 A_SetScale(scale.y*2);
		---- BCD -1{frame=random(1,3);}wait;
	}
}
class HDGunSmoke:HDSmoke{
	default{
		scale 0.3;renderstyle "add";alpha 0.4;
		hdpuff.decel 0.97;
		hdpuff.fade 0.8;
		hdpuff.grow 0.06;
		hdpuff.minalpha 0.01;
		hdpuff.startvelz 0;
	}
	override void postbeginplay(){
		super.postbeginplay();
		a_changevelocity(cos(pitch)*4,0,-sin(pitch)*4,CVF_RELATIVE);
		vel+=(frandom(-0.1,0.1),frandom(-0.1,0.1),frandom(0.4,0.9));
	}
}
class HDGunSmokeStill:HDGunSmoke{
	override void postbeginplay(){
		HDSmoke.postbeginplay();
	}
}
class HDFlameRed:HDPuff{
	default{
		renderstyle "add";
		alpha 0.6;scale 0.3;gravity 0.05;
		
		hdpuff.fadeafter 3;
		hdpuff.grow -0.01;
		hdpuff.fade 0.8;
		hdpuff.decel 0.8;
		hdpuff.startvelz 4;
	}
	states{
	spawn:
		BAL1 A 0 nodelay A_SpawnItemEx("HDRedFireLight",flags:SXF_SETTARGET);
		BAL1 ABCDE 1;
		TNT1 A 0
		{
			ThinkerIterator it = ThinkerIterator.Create('HDFlameRed', STAT_USER);
			Actor a = null;
			int count = 0;
			while (a = Actor(it.Next()))
			{
				if (Distance3D(a) <= 64)
				{
					count++;
				}
				if (count == 4)
				{
					SetStateLabel('Death');
					break;
				}
			}
		}
		stop;
	death:
		TNT1 A 0{
			grow=0.01;
			fade=0.9;
			decel=0.9;
			vel.z+=2;
			minalpha=0.1;
			addz(-vel.z);
			A_SetTranslucent(0.6,0);
			scale=(1.2,1.2);gravity=0.1;
		}
		RSMK CD -1{frame=random(0,3);}
		wait;
	}
}
class HDRedFireLight:PointLight{
	default{+dynamiclight.additive}
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=60;
		args[1]=40;
		args[2]=10;
		args[3]=64;
		args[4]=0;
	}
	override void tick(){
		if(!target||args[3]<1){destroy();return;}
		args[3]=int(frandom(0.8,1.09)*args[3]);
		setorigin(target.pos,true);
	}
}
class HDFlameRedBig:HDActor{
	default{
		+nointeraction
		+rollsprite +rollcenter +spriteangle +bright
		translation 1;
		spriteangle 90;
		renderstyle "add";
	}
	void A_FlameFade(){
		A_FadeOut(frandom(-0.002,0.02));
		addz(frandom(-0.1,0.1));
		scale*=frandom(0.98,1.01);
		scale.x*=randompick(1,1,-1);
		if(target)setorigin(target.pos+(
			(frandom(-target.radius,target.radius),frandom(-target.radius,target.radius))*0.6,
			frandom(0,target.height*0.6))
		,true);
	}
	void A_SmokeFade(){
		actor sss=spawn("HDSmoke",(pos.x,pos.y,pos.z+36*scale.y),ALLOW_REPLACE);
		sss.scale=scale;
	}
	states{
	spawn:
		FIR7 ABABABABABAB 1 A_FlameFade();
		FIR7 A 0 A_SmokeFade();
		stop;
	}
}
class HDSmokeSmall:HDFlameRed{
	override void postbeginplay(){
		hdactor.postbeginplay();
		setstatelabel("death");
	}
}
class HDExplosion:IdleDummy{
	default{
		+forcexybillboard +bright
		alpha 0.9;renderstyle "add";
		deathsound "world/explode";
	}
	states{
	spawn:
	death:
		MISL B 0 nodelay{
			if(max(abs(pos.x),abs(pos.y),abs(pos.z))>=32768){destroy();return;}
			vel.z+=2;
			A_StartSound(deathsound,CHAN_BODY);
			let xxx=spawn("HDExplosionLight",pos);
			xxx.target=self;
		}
		MISL BB 0 A_SpawnItemEx("ParticleWhiteSmall", 0,0,0, vel.x+random(-2,2),vel.y+random(-2,2),vel.z,0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		MISL BBBB 0 A_SpawnItemEx("HDSmoke", 0,0,0, vel.x+frandom(-2,2),vel.y+frandom(-2,2),vel.z,0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
		MISL B 0 A_Jump(256,"fade");
	fade:
		MISL B 1 A_FadeOut(0.1);
		MISL C 1 A_FadeOut(0.2);
		MISL DD 1 A_FadeOut(0.2);
		TNT1 A 20;
		stop;
	}
}
class HDExplosionLight:PointLight{
	default{
		stamina 128;
	}
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=240;
		args[1]=200;
		args[2]=60;
		args[3]=stamina;
		args[4]=0;
	}
	override void tick(){
		args[3]=int(frandom(0.3,0.4)*args[3]);
		if(args[3]<1)destroy();
	}
}
//transfer sprite frame fader
//deathheight = amount to fade every 4 tics
class HDCopyTrail:IdleDummy{
	default{
		+noclip +rollsprite +rollcenter +nointeraction
		deathheight 0.6;
		renderstyle "add";
	}
	states{spawn:#### A -1;stop;}
	override void Tick(){
		clearinterpolation();
		if(isfrozen())return;
		scale.x+=frandom(-0.01,0.01);scale.y=scale.x;
		accuracy++;
		if(accuracy>=4){
			accuracy=0;
			alpha*=deathheight;
			vel*=deathheight;
			if(alpha<0.04){destroy();return;}
		}
		setorigin(pos+vel,true);
		//don't even bother with nexttic, it's just one frame!
	}
}
extend class HDActor{
	actor A_Trail(double spread=0.6){
		vector3 v=(frandom(-1,1),frandom(-1,1),frandom(-1,1));
		bool gbg;actor aaa;
		[gbg,aaa]=A_SpawnItemEx("HDCopyTrail",
			0,0,0,vel.x+v.x,vel.y+v.y,vel.z+v.z,0,
			SXF_TRANSFERALPHA|SXF_TRANSFERRENDERSTYLE|SXF_TRANSFERSCALE|
			SXF_TRANSFERPITCH|SXF_TRANSFERSPRITEFRAME|SXF_TRANSFERROLL|
			SXF_ABSOLUTEVELOCITY|SXF_TRANSFERTRANSLATION|SXF_NOCHECKPOSITION|
			SXF_TRANSFERSTENCILCOL|SXF_TRANSFERPOINTERS
		);
		return aaa;
	}
}
class HDFader:HDCopyTrail{
	default{+rollsprite +rollcenter +noblockmap +nointeraction deathheight 0.1; renderstyle "translucent";}
	override void Tick(){
		clearinterpolation();
		if(isfrozen()||level.time&(1|2))return;
		setorigin(pos+vel,true);
		setz(clamp(pos.z,floorz,ceilingz));
		a_fadeout(deathheight);
	}
}
//thinker used to generate distant sound
//DistantNoise.Make(self,"world/rocketfar");
class DistantNoise:Thinker{
	sound distantsound;
	int distances[MAXPLAYERS];
	int ticker;
	double volume,pitch;
	static void Make(
		actor source,
		sound distantsound,
		double volume=1.,
		double pitch=1.
	){
		DistantNoise dnt=new("DistantNoise");
		dnt.ticker=0;
		dnt.distantsound=distantsound;
		dnt.volume=clamp(0.,volume,5.);
		dnt.pitch=pitch;
		for(int i=0;i<MAXPLAYERS;i++){
			if(
				playeringame[i]
				&&!!players[i].mo
			){
				dnt.distances[i]=int(players[i].mo.distance3d(source)/HDCONST_SPEEDOFSOUND);
			}else dnt.distances[i]=-1;
		}
	}
	override void Tick(){
		if(level.isfrozen())return;
		int playersleft=0;
		for(int i=0;i<MAXPLAYERS;i++){
			if(distances[i]<0)continue;
			if(
				!!players[i].mo
			){
				playersleft++;
				if(distances[i]==ticker){
					distances[i]=-1;
					//for volumes greater than 1, play the sound on top of itself until spent
					double thisvol=volume;
					while(thisvol>0){
						players[i].mo.A_StartSound(
							distantsound,CHAN_DISTANT,
							CHANF_OVERLAP|CHANF_LOCAL,
							min(1.,thisvol),  //if we ever stop needing this clamp, delete the loop
							pitch:pitch
						);
						thisvol-=1.;
					}
				}
			}
		}
		if(playersleft)ticker++;
		else destroy();
	}
}
//Quake effect affecting each player differently depending on distance
//DistantQuaker.Quake(self,8,40,4096,10,256,512,256);
class DistantQuaker:IdleDummy{
	int intensity;
	double frequency;
	bool wave;
	//Quake effect affecting each player differently depending on distance
	//DistantQuaker.Quake(self,8,40,4096,10,256,512,256);
	static void Quake(
		actor caller,
		int intensity=3,
		int duration=35,
		double quakeradius=1024,
		int frequency=10,
		double speed=HDCONST_SPEEDOFSOUND,
		double minwaveradius=HDCONST_MINDISTANTSOUND,
		double dropoffrate=HDCONST_MINDISTANTSOUND
	){
		if(
			caller.ceilingpic==skyflatnum
			||caller.ceilingz-caller.floorz>HDCONST_MINDISTANTSOUND
		){
			intensity=clamp(intensity-1,1,9);
			duration=int(0.9*duration);
		}
		double dist;
		for(int i=0;i<MAXPLAYERS;i++){
			if(playeringame[i] && players[i].mo){
				dist=players[i].mo.distance3d(caller);
				if(dist<=quakeradius){
					let it=DistantQuaker(caller.spawn("DistantQuaker",players[i].mo.pos,ALLOW_REPLACE));
					if(it){
						if(dist<=dropoffrate)it.intensity=intensity;
							else it.intensity=int(clamp(intensity-floor(dist/dropoffrate),1,9));
						if(dist>minwaveradius)it.wave=true;else it.wave=false;  
						if(it.intensity<3)it.deathsound="null";
							else it.deathsound="world/quake";
						it.stamina=int(dist/speed);
						it.mass=duration;
						it.frequency=frequency;
						it.target=players[i].mo;
					}
				}
			}
		}
	}
	states{
	spawn:
		TNT1 A 1 nodelay A_SetTics(stamina);
		TNT1 A 0{
			if(max(abs(pos.x),abs(pos.y),abs(pos.z))>32000)return;
			if(wave){
				A_StartSound("weapons/subfwoosh",CHAN_AUTO,volume:0.1*intensity);
				if(
					target
					&&target.pos.z-target.floorz<256
				)A_QuakeEx(
						0,0,intensity,mass,0,16,deathsound,
						QF_SCALEDOWN|QF_WAVE,0,0,frequency,0,int(mass*0.62)
					);
			}else{
				A_QuakeEx(
					intensity*2,intensity*2,intensity*2,mass,0,16,deathsound,
					QF_SCALEDOWN,highpoint:int(mass*0.62)
				);
			}
		}
		TNT1 A 1{
			if(target && mass>0){
				mass--;
				setxyz(target.pos);
			}else{
				destroy();
				return;
			}
		}wait;
	}
}
//SO MUCH BLOOD
class BloodSplatSilent:HDPuff{
	default{
		alpha 0.8;gravity 0.3;
		hdpuff.startvelz 1.6;
		hdpuff.fadeafter 0;
		hdpuff.decel 0.86;
		hdpuff.fade 0.88;
		hdpuff.grow 0.03;
		hdpuff.minalpha 0.03;
	}
	states{
	spawn:
		BLUD ABC 4{
			if(floorz>=pos.z){
				bflatsprite=true;bmovewithsector=true;bnointeraction=true;
				setz(floorz);vel=(0,0,0);
				fade=0.97;
			}
		}wait;
	}
}
class BloodSplat:BloodSplatSilent replaces Blood{
	default{
		seesound "misc/bulletflesh";
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(!bambush)A_StartSound(seesound,CHAN_BODY,CHANF_OVERLAP,0.2);
	}
}
class BloodSplattest:BloodSplat replaces BloodSplatter{}
class NotQuiteBloodSplat:BloodSplat{
	override void postbeginplay(){
		super.postbeginplay();
		A_StartSound("misc/bulletflesh",CHAN_BODY,CHANF_OVERLAP,0.02);
		actor p=spawn("PenePuff",pos,ALLOW_REPLACE);
		p.target=target;p.master=master;p.vel=vel*0.3;
		scale*=frandom(0.2,0.5);
	}
}
class ShieldNotBlood:NotQuiteBloodSplat{
	override void postbeginplay(){
		bloodsplat.postbeginplay();
		if(
			hdmobbase(target)
			&&hdmobbase(target).bbloodlesswhileshielded
			&&target.countinv("HDMagicShield")>50
		){
			A_SetTranslucent(1,1);
			grav=-0.6;
			scale*=0.4;
			setstatelabel("spawnshield");
			bnointeraction=true;
			return;
		}
		A_StartSound("misc/bulletflesh",CHAN_AUTO,volume:0.02);
		actor p=spawn("PenePuff",pos,ALLOW_REPLACE);
		p.target=target;p.master=master;p.vel=vel*0.3;
		scale*=frandom(0.2,0.5);
	}
	states{
	spawnshield:
		TFOG ABCDEFGHIJ 3 bright A_FadeOut(0.05);
		stop;
	}
}
class ShieldNeverBlood:IdleDummy{
	default{
		+forcexybillboard +rollsprite +rollcenter
		renderstyle "add";
	}
	override void postbeginplay(){
		super.postbeginplay();
		scale*=frandom(0.2,0.5);
		roll=frandom(0,360);
	}
	states{
	spawn:
		TFOG ABCDEFGHIJ 3 bright A_FadeOut(0.08);
		stop;
	}
}
class BloodTrail:HDPuff{
	default{
		alpha 0.7;scale 0.2;gravity 0.02;
	}
	states{
	spawn:
		BLOD A -1;
	}
}
class MegaBloodSplatter:IdleDummy{
	override void postbeginplay(){
		actor.postbeginplay();
		if(!A_CheckSight("null")){
			for(int i=0;i<20;i++){
				actor b=spawn("BloodSplatSilent",self.pos,ALLOW_REPLACE);
				b.vel=self.vel+(random(-4,4),random(-4,4),random(-1,7));
				b.translation=self.translation;
			}
		}
		destroy();
	}
}
class HDBloodTrailFloor:IdleDummy{
	default{
		+flatsprite +movewithsector
		height 1;radius 1;alpha 0.6;
	}
	override void postbeginplay(){
		super.postbeginplay();
		frame=random(0,3);
		scale*=frandom(0.6,1.2);
		setz(floorz);
	}
	states{
	spawn:
		BLUD # 100 nodelay A_FadeOut(0.05);
		wait;
		BLUD ABCD 0;
		stop;
	}
}
//Ominous shards of green or blue energy
class FragShard:IdleDummy{
	default{
		renderstyle "add";+forcexybillboard;scale 0.3;alpha 0;
	}
	override void tick(){
		if(isfrozen())return;
		trymove(self.pos.xy+vel.xy,true);
		if(alpha<1)alpha+=0.05;
		addz(vel.z,true);
		NextTic();
	}
	states{
	spawn:
		BFE2 D 20 bright nodelay{
			if(stamina>0) A_SetTics(stamina);
		}stop;
	}
}
extend class HDActor{
	//A_ShardSuck(self.pos+(0,0,32),20);
	virtual void A_ShardSuck(vector3 aop,int range=4,bool forcegreen=false){
		actor a=spawn("FragShard",aop,ALLOW_REPLACE);
		a.setorigin(aop+(random(-range,range)*6,random(-range,range)*6,random(-range,range)*6),false);
		a.vel=(aop-a.pos)*0.05;
		a.stamina=20;
		if(forcegreen)a.A_SetTranslation("AllGreen");
	}
}
//Teleport fog
class TeleFog:IdleDummy replaces TeleportFog{
	default{
		renderstyle "add";alpha 0.6;
	}
	override void postbeginplay(){
		actor.postbeginplay();
		scale.x*=randompick(-1,1);
		A_StartSound("misc/teleport");
	}
	states{
	spawn:
		TFOG AA 2 nodelay bright light("TLS1") A_FadeIn(0.2);
		TFOG BBCCCDDEEFGHII 2 bright light("TLS1"){
			A_ShardSuck(pos+(0,0,frandom(24,48)),forcegreen:true);
		}
		TFOG JJJJ random(2,3) bright light("TLS1"){
			alpha-=0.2;
			A_ShardSuck(pos+(0,0,frandom(24,48)),forcegreen:true);
		}stop;
	nope:
		TNT1 A 20 light("TLS1");
		stop;
	}
}
//Electro shit
const HDCONST_ZAPARCDEFAULTDEV=1.4;
extend class HDActor{
	static void ParticleZigZag(
		actor caller,
		vector3 orig,
		vector3 dest,
		int segments=12,
		bool relpos=false,  //if true, treats o/d inputs as relative to caller
		vector3 pvel=(0,0,0),
		double dev=HDCONST_ZAPARCDEFAULTDEV  //amount of deviation in each node
	){
		if(orig==dest)return;
		if(!relpos){
			dest-=caller.pos;
			orig-=caller.pos;
		}
		array<double> arcx;
		array<double> arcy;
		array<double> arcz;
		arcx.clear();
		arcy.clear();
		arcz.clear();
		vector3 frac=(dest-orig)/segments;
		dev*=max(abs(frac.x),abs(frac.y),abs(frac.z));
		int lastpoint=segments-1;
		for(int i=0;i<segments;i++){
			if(i==lastpoint){
				arcx.push(dest.x);
				arcy.push(dest.y);
				arcz.push(dest.z);
			}else{
				arcx.push(frandom(-dev,dev)+orig.x+frac.x*i);
				arcy.push(frandom(-dev,dev)+orig.y+frac.y*i);
				arcz.push(frandom(-dev,dev)+orig.z+frac.z*i);
			}
		}
		int arx=arcx.size()-1;
		for(int i=0;i<arx;i++){
			int ii=i+1;
			vector3 firstpoint=(arcx[i],arcy[i],arcz[i]);
			vector3 lastpoint=(arcx[ii],arcy[ii],arcz[ii]);
			vector3 pointfrac=lastpoint-firstpoint;
			int pointdist=int(pointfrac.length())>>1;
			pointfrac=pointfrac.unit()*2.;
			for(int j=0;j<pointdist;j++){
				caller.A_SpawnParticle(
					"azure",SPF_FULLBRIGHT,20,frandom(2,4),0,
					firstpoint.x,
					firstpoint.y,
					firstpoint.z,
					pvel.x+frandom(-0.1,0.1),pvel.y+frandom(-0.1,0.1),pvel.z+frandom(-0.1,0.1)
				);
				firstpoint+=pointfrac;
			}
		}
	}
	static void ZapArc(
		actor a1,
		actor a2=null,
		int flags=0,
		double radius=0,
		double height=0,
		vector3 pvel=(0,0,0),
		double dev=HDCONST_ZAPARCDEFAULTDEV
	){
		if(!a1)a1=a2;
		vector3 a1pos,a2pos;
		if(
			!a2
			||a1==a2
		){
			if(!a2)a2=a1;
			if(!a1)return;
			if(radius<=0)radius=a1.radius*1.2;
			if(height<=0)height=a1.height*1.1;
			double flr=a1.pos.z>a1.floorz?a1.height*-0.1:0;
			a1pos=(radius*(frandom(-1,1),frandom(-1,1)),frandom(flr,height));
			a2pos=(radius*(frandom(-1,1),frandom(-1,1)),frandom(flr,height));
		}else{
			a1pos=(a1.pos.xy,a1.pos.z+a1.height*0.6);
			a2pos=(a2.pos.xy,a2.pos.z+a2.height*0.6);
			if(flags&ARC2_RANDOMSOURCE){
				double radius=a1.radius*0.6;
				a1pos.xy+=(frandom(-radius,radius),frandom(-radius,radius));
				a1pos.z+=a1.height*frandom(-0.3,0.2);
			}
			if(flags&ARC2_RANDOMDEST){
				double radius=a2.radius*0.6;
				a2pos.xy+=(frandom(-radius,radius),frandom(-radius,radius));
				a2pos.z+=a2.height*frandom(-0.3,0.2);
			}
		}
		ParticleZigZag(a1,a1pos,a2pos,relpos:(a1==a2),pvel:pvel,dev:dev);
		if(!(flags&ARC2_SILENT)){
			a1.A_StartSound("misc/zap",CHAN_ARCZAP,CHANF_OVERLAP);
			a2.A_StartSound("misc/zap2",CHAN_ARCZAP,CHANF_OVERLAP);
			a2.A_StartSound("misc/zap3",CHAN_ARCZAP,CHANF_OVERLAP);
		}
	}
	enum ArcActorsFlags{
		ARC2_RANDOMSOURCE=1,
		ARC2_RANDOMDEST=2,
		ARC2_SILENT=4,
	}
	//sit around and zap nearby shit at random
	static void ArcZap(
		actor caller,
		double rad=0,
		int maxdamage=8,
		bool indiscriminate=false
	){
		array<actor> zappables;zappables.clear();
		if(!rad)rad=frandom(32,128);
		blockthingsiterator it=blockthingsiterator.create(caller,rad);
		while(it.next()){
			actor itt=it.thing;
			if(
				itt.bshootable
				&&(
					indiscriminate
					||caller.ishostile(itt)
				)
				&&caller.distance3dsquared(itt)<=(rad*rad)
				&&caller.checksight(itt)
			)zappables.push(itt);
		}
		actor itt=caller;
		if(zappables.size())itt=zappables[random(0,zappables.size()-1)];
		ZapArc(caller,itt,ARC2_RANDOMSOURCE,rad,rad*0.3,dev:0.8);
		if(itt)itt.damagemobj(caller,caller,random(1,maxdamage),"electrical");
	}
}