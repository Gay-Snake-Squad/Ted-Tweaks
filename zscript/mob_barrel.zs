// ------------------------------------------------------------
// Killer(?) Barrel
// ------------------------------------------------------------
class HDBarrel:HDMobBase replaces ExplosiveBarrel{
	int musthavegremlin;
	property musthavegremlin:musthavegremlin;
	class<actor> lighttype;
	property lighttype:lighttype;
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Killer Barrel"
		//$Sprite "BAR1A0"
		+solid +shootable
		+activatemcross +canpass +nodropoff
		+fixmapthingpos +dontgib
		+hdmobbase.doesntbleed
		+hdmobbase.headless
		-countkill
		-ismonster
		+hdmobbase.noshootablecorpse
		maxstepheight 4;
		maxdropoffheight 4;
		damagefactor "hot",1.2;
		damagefactor "cold",1.2;
		damagefactor "Balefire",0.1;
		radius 11;height 34;
		health 100;mass 200;gibhealth 200;
		painchance 256;
		pushfactor 0.1;
		deathsound "world/barrelx";
		translation "176:191=96:111","64:79=104:111";
		bloodcolor "ba ff 86";bloodtype "NotQuiteBloodSplat";
		obituary "%o was rolled by a barrel.";
		attacksound "barrel/missile";
		hdbarrel.musthavegremlin 0; //0 random, -1 never, 1 always
		hdbarrel.lighttype "HDBarrelLight";
		tag "barrel";
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(
			self is "HDFireCan"
			&&(
				Wads.CheckNumForName("FCANA0",wads.ns_sprites,-1,false)==-1
				||Wads.CheckNumForName("FIREC0",wads.ns_sprites,-1,false)==-1
				//apparently D1 *has* FCAN just not FIRE!?
			)
		){
			A_SpawnItemEx("HDBarrel",flags:SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS);
			destroy();return;
		}
		if(
			musthavegremlin>0
			||(
				!musthavegremlin
				&&!sv_nomonsters
				&&(random(0,99)<hd_killerbarrels)
			)
		){
			painsound="barrel/pain";
			A_SpawnItemEx("BarrelGremlin",flags:SXF_NOCHECKPOSITION|SXF_SETMASTER);
		}
		let lll=spawn(lighttype,pos,ALLOW_REPLACE);
		lll.target=self;
	}
	void A_BarrelMove(){
		if(floorz!=pos.z)return;
		A_FaceTarget();
		angle+=random(-135,135);
		A_StartSound("barrel/walk",CHAN_BODY);
		vel.xy+=(cos(angle),sin(angle))*5;
		setstatelabel("inertjiggle");
	}
	virtual void A_BarrelAttack(){
		A_FaceTarget(0,0);
		if(
			HDMobAI.TryShoot(self,32,0,9,9)
		){
			A_StartSound(attacksound,CHAN_WEAPON);
			A_SpawnProjectile("BaleBall",40,flags:CMF_AIMDIRECTION,pitch);
		}
		setstatelabel("inertjiggle");
	}
	void A_BarrelCheckCrowd(){
		int bcc=0;
		barrelexplodemarker bpm;
		thinkeriterator bexpm=ThinkerIterator.create("BarrelExplodeMarker", STAT_USER + 1);
		while(bpm=barrelexplodemarker(bexpm.next(true))){
			bcc++;
			if(bcc>random(1,12)){
				setstatelabel("waittoexplode");
				break;
			}
		}
	}
	states{
	spawn:
		BAR1 AB 10;
		loop;
	pain:
		#### B 1 A_Pain();
	inertjiggle:
		#### B 1 A_StartSound("barrel/jiggle",CHAN_BODY,CHANF_OVERLAP);
		#### ABABAABBAAABBB 1;
		---- A 0 A_Jump(256,"spawn");
	death:
		#### A 0;
		---- A 0 A_NoBlocking();
		---- A 0 A_SetSize(-1,default.height);
	waittoexplode:
		---- A 0 A_SetSolid();
		---- A 0 A_SetShootable();
		#### ABABAB random(1,3);
		#### B random(1,3) A_BarrelCheckCrowd();
	reallyexplode:
		BEXP C 0{
			A_UnsetSolid();
			A_UnsetShootable();
			A_NoBlocking();
			A_SetSize(-1,deathheight);
			bsolid=false;
            Thinker t = new("BarrelExplodeMarker");
			t.ChangeStatNum(STAT_USER + 1);

			actor xpl=spawn("HDExplosionLight",pos,ALLOW_REPLACE);
			xpl.target=self;xpl.stamina=256;
		}
		BEXP CCC 1 bright{
			if(stamina<3){
				for(int i=0;i<16;i++){
					actor aaa=spawn("HugeWallChunk",(pos.xy,pos.z+frandom(0,height)),ALLOW_REPLACE);
					aaa.vel=(frandom(-10,10),frandom(-10,10),frandom(4,20));
					if(aaa.vel dot aaa.vel < 100)
						aaa.A_SetTranslation((KillerFireCan(self)||random(0,2))?"Charred":"Booger");
					aaa.scale*=frandom(0.8,1.8);
				}
			}
			actor a=spawn("HDExplosion",self.pos+(random(-2,2),random(-2,2),random(12,32)),ALLOW_REPLACE);
			a.vel=self.vel+(random(-1,1),random(-1,1),random(-1,2));
		}
		BEXP C 0 A_BarrelBlast();
		BEXP D 2 bright{
			if(painsound!="barrel/pain")A_SpawnItemEx("BFGNecroShard",0,0,24,0,0,8,0,SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS,64);
			A_SpawnChunks("HDSmokeChunk",random(2,5),7,16);
			A_Scream();
			DistantQuaker.Quake(self,6,42,512,10);
			A_StartSound("world/explode");
			DistantNoise.Make(self,"world/rocketfar");
		}
		BEXP EEEEEEE 0 A_SpawnItemEx ("HDSmoke", random(-6,6),random(-6,6),random(12,32), vel.x+random(-1,1),vel.y+random(-1,1),vel.z+random(1,2), 0,168);
		BEXP EEE 2 bright A_FadeOut(0.3);
		POB1 A 0{
			A_SetSize(-1,8);
			A_SetScale(0.7);
			A_SetRenderstyle(1,Style_Normal);
			setstatelabel("dying");
			A_GiveInventory("Heat",6660);
			bshootable=true;
			bpushable=false;
			bbright=false;
		}
	dying:
		POB1 AAAAAAA 50{
			A_Immolate(self,self.target,random(12,24));
			if(!random(0,2)) A_SpawnChunks("HDSmokeChunk",1,2,12);
		}
		POB1 A -1{
			A_StartSound("vile/firestrt",CHAN_AUTO,volume:0.4);
			A_SpawnChunks("HDSmoke",8,0,3);
		}stop;
	}
	virtual void A_BarrelBlast(){
		A_HDBlast(
			random(128,256),random(128,256),0,"Balefire",
			256,256,0,true,
			fragradius:512,fragtype:"HDB_scrap",
			immolateradius:128,immolateamount:random(10,40),immolatechance:36
		);
		A_BarrelFrags();
	}
	void A_BarrelFrags(){
		for(int i=0;i<100;i++){
			let aaa=spawn("HDB_scrap",(pos.xy,pos.z+frandom(0,height)));
			aaa.target=self;
			aaa.vel=(angletovector(frandom(0,360),frandom(80,600)),frandom(-20,100));
			aaa.speed=vel.length();
		}
	}
}
class BarrelExplodeMarker:Thinker{
	int timer;
	override void Tick(){
		if(level.isfrozen())return;
		timer++;
		if(timer>200)destroy();
	}
}
class BarrelGibs:IdleDummy{
	default{
		+movewithsector;
		translation "176:191=96:111","64:79=104:111";
	}
	states{
	spawn:
		POB1 A 10;
		POB1 A -1{
			A_Stop();
			setz(floorz);
		}stop;
	}
}
class HDBarrelLight:PointLight{
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=3;
		args[1]=50;
		args[2]=10;
		args[3]=23;
		args[4]=0;
	}
	override void tick(){
		if(!target||target.health<1){destroy();return;}
		setorigin((target.pos.xy,target.pos.z+36),true);
		args[3]=random(20,26);
	}
}
// ------------------------------------------------------------
// Killer(?) Fire Can
// ------------------------------------------------------------
class HDFireCan:HDBarrel replaces BurningBarrel{
	int fireticker;
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Flaming Barrel"
		//$Sprite "FCANA0"
		+bright
		health 100;
		translation "176:191=96:111","64:79=104:111";
		bloodcolor "ba ff 86";bloodtype "NotQuiteBloodSplat";
		obituary "%o should try again. It's a killer fire CAN, not a killer fire CAN'T!";
		attacksound "vile/firestrt";
		missiletype "BarrelFlame";
		hdbarrel.lighttype "HDFireCanLight";
		tag "burning barrel";
	}
	override void A_BarrelAttack(){
		A_FaceTarget(0,0);
		pitch-=random(1,12);
		if(
			HDMobAI.TryShoot(self,32,128,9,9)
		){
			if(distance3d(target)<256){
				setstatelabel("flamethrow");
				return;
			}else{
				A_StartSound(attacksound);
				A_SpawnProjectile("BarrelFlame",40,flags:CMF_AIMDIRECTION);
			}
		}
		else if(!random(0,10)){
			//move
			A_FaceTarget();
			angle+=random(-135,135);
			A_StartSound("barrel/walk");
			vel.xy+=(cos(angle),sin(angle))*5;
		}
		setstatelabel("inertjiggle");
	}
	override void tick(){
		super.tick();
		if(isFrozen())return;
		if(!bkilled){
			fireticker++;
			if(fireticker<6)return;
			fireticker=random(-1,2);
			A_StartSound("misc/firecrkl",CHAN_BODY,CHANF_OVERLAP,volume:0.07);
			A_StartSound("misc/fwoosh",CHAN_BODY,CHANF_OVERLAP,volume:0.04,attenuation:0.6);
			actor a=spawn("HDSmoke",pos+(0,0,32),ALLOW_REPLACE);
			a.vel=vel+(frandom(-1,1),frandom(-1,1),frandom(2,3));
		}
	}
	override void A_BarrelBlast(){
		A_HDBlast(
			random(128,256),random(64,128),0,"hot",
			pushradius:256,pushamount:256,fullpushradius:0,pushmass:true,
			immolateradius:256,immolateamount:random(3,12),immolatechance:56
		);
		A_BarrelFrags();
	}
	states{
	spawn:
		FCAN AB random(1,3);
		loop;
	flamethrow:
		FCAN ABABABAB 2 bright{
			A_StartSound("misc/firecrkl");
			A_SpawnProjectile("BarrelFlame2",40,flags:CMF_AIMDIRECTION);
		}
		FCAN A 0 A_Jump(256,"spawn");
	dying:
		POB1 AAAAAAAAAAAAAAAAA 30{
			A_Immolate(self,self.target,random(24,48));
			if(!random(0,1))A_SpawnChunks("HDSmokeChunk",1,2,12);
		}
		POB1 A -1{
			A_SetRenderstyle(1,Style_Normal);
			A_StartSound("vile/firestrt",CHAN_AUTO,volume:0.4);
			if(!random(0,4))A_HDBlast(
				random(12,128),random(2,4),64,"Balefire"
			);
			A_SpawnChunks("HDSmoke",8,4,12);
		}
	}
}
//the fire can fire
class BarrelFlameTail:HDFireballTail{
	default{
		-rollsprite;
		scale 0.6;radius 0.3;
	}
	states{
		spawn:
			FIRE CD 2;
			loop;
	}
}
//flamethrower projectile
class BarrelFlame2:HDFireball{
	default{
		gravity 0.4;scale 0.2;
		height 4;radius 4;
		damagefactor(1);stamina 40;
		damagetype "hot";
	}
	override void postbeginplay(){
		super.postbeginplay();
		A_StartSound("misc/firecrkl",CHAN_BODY,CHANF_LOOP,0.8);
	}
	states{
	spawn:
		FIRE CD 2 bright{
			A_Trail(0.3);
			scale*1.05;
			alpha*0.92;
			stamina-=2;
			if(!stamina) ExplodeMissile();
		}loop;
	death:
		FIRE D 0{
			A_HDBlast(
				immolateradius:stamina+4,
				immolateamount:stamina+4,
				hurtspecies:false
			);
			if(blockingmobj)A_Immolate(blockingmobj,target,random(0,4)+stamina);
			actor a;
			for(int i=0;i<3;i++){
				a=spawn("HDSmoke",pos+(random(-2,2),random(-2,2),random(1,3)),ALLOW_REPLACE);
				a.vel+=(random(-1,1),random(-1,1),3);
			}
		}
		FIRE EFGH 1 bright A_FadeOut(0.1);
		stop;
	}
}
//launched projectile
class BarrelFlame:HDFireball{
	default{
		gravity 0.6;scale 0.3;
		missiletype "BarrelFlameTail";
	}
	override void postbeginplay(){
		super.postbeginplay();
		A_StartSound("misc/firecrkl",CHAN_BODY,CHANF_LOOP,0.8);
	}
	states{
	spawn:
		FIRE CDCDCDCD 2 bright A_FBTail();
	see:
		FIRE CD 2 bright;
		loop;
	death:
		FIRE D 0{
			if(blockingmobj){
				A_Immolate(blockingmobj,target,random(24,48));
			}else{
				actor a=spawn("BarrelFireCrawler",pos,ALLOW_REPLACE);
				if(target)a.target=target.target;a.master=target;
				a=spawn("HDSmoke",pos,ALLOW_REPLACE);
				a.vel.z+=2;
				a.A_StartSound("vile/firestrt",volume:0.6);
				destroy();
				return;
			}
			A_HDBlast(
				immolateradius:24,
				immolateamount:random(8,16),
				hurtspecies:false
			);
		}
		FIRE EFGH 3 bright;
		stop;
	}
}
class BarrelFireCrawler:HDActor{
	actor a;
	default{
		+shootable;+canpass;-noblockmonst;
		height 54;radius 16;speed 12;
		+noblooddecals -solid +nofear +bright
		radius 8;height 10;meleerange 12;renderstyle "add";maxstepheight 64;maxdropoffheight 64;
		speed 5;health 20;bloodtype "HDSmoke";
	}
	override void postbeginplay(){
		super.postbeginplay();
		scale.x*=randompick(-1,1)*frandom(0.8,1.2);
		scale.y*=frandom(0.8,1.2);
		A_GiveInventory("HDFireEnder",999); //do not set the fire on fire
		A_StartSound("misc/firecrkl",CHAN_BODY,CHANF_LOOP,0.6);
	}
	states{
	spawn:
		FIRE ABAB 2 bright{
			//chase constantly
			if(!target || !master || master.bkilled){
				A_Die("burnout");
				return;
			}
			A_Chase(); //no need for all that fancy shit
		}
		FIRE A 0{
			A_Trail(2);
			a=spawn("HDSmoke",pos,ALLOW_REPLACE);
			a.vel=vel+(0,0,2);a.scale=scale;
			if(!random(0,10))damagemobj(self,self,1,"none");
		}
		loop;
	melee:
		FIRE A 0{
			if(target)A_Immolate(target,master,int(frandom(24,48)*scale.x));
			A_Die("burnout");
		}goto death;
	pain.hot:
		FIRE A 0{
			A_GiveInventory("HDFireEnder",999);
		}goto spawn;
	death:
		FIRE A 0{
			A_NoBlocking();
			for(int i=0;i<4;i++){
				if(scale.x>=0.4 && !random(0,2)){
					a=spawn("BarrelFireCrawler",pos,ALLOW_REPLACE);
					HDMobAI.Resize(a,self.scale.x*0.6,0.1);
					if(target){
						a.target=target.target;
						a.master=target;
					}
					a.vel=self.vel+(random(-2,2),random(-2,2),random(1,3));
				}else{
					a=spawn("HDSmokeChunk",pos,ALLOW_REPLACE);
					a.target=target;a.master=master;
					a.vel=self.vel+(random(-5,5),random(-5,5),random(3,5));
				}
			}
			a=spawn("HDSmoke",pos,ALLOW_REPLACE);
			a.vel.z+=2;
			destroy();
		}stop;
	death.burnout:
		FIRE A 0{
			A_StartSound("misc/firecrkl",CHAN_BODY);
			A_NoBlocking();
		}
		FIRE CDEFGH 2{
			A_Trail();
			A_FadeOut(0.05);
		}stop;
	}
}
class HDFireCanLight:HDBarrelLight{
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=160;
		args[1]=120;
		args[2]=60;
		args[3]=42;
		args[4]=0;
	}
}
//map replacers
class KillerBarrel:HDBarrel{
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Killer Barrel"
		//$Sprite "BAR1A0"
		hdbarrel.musthavegremlin 1;
	}
}
class KillerFireCan:HDFireCan{
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Killer Flaming Barrel"
		//$Sprite "FCANA0"
		hdbarrel.musthavegremlin 1;
	}
}
class InnocentBarrel:HDBarrel{
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Inert Barrel"
		//$Sprite "BAR1A0"
		hdbarrel.musthavegremlin -1;
	}
}
class InnocentFireCan:HDFireCan{
	default{
		//$Category "Monsters/Hideous Destructor"
		//$Title "Inert Flaming Barrel"
		//$Sprite "FCANA0"
		hdbarrel.musthavegremlin -1;
	}
}
// ------------------------------------------------------------
// Barrel Killer
// ------------------------------------------------------------
class BarrelGremlin:HDActor{
	default{
		+ismonster +countkill -solid +noblockmap
		radius 0;height 0;
		-shootable
		health 1;
	}
	bool hasmoved;
	void A_GremlinHunt(){
		let bbb=HDBarrel(master);
		if(
			!bbb
			||bbb.health<1
		){
			bshootable=true;
			A_Die();
			return;
		}
		if(
			!target
			||target.health<1
		){
			target=null;
			hasmoved=false;
			A_LookEx(
				LOF_NOSOUNDCHECK|LOF_DONTCHASEGOAL|LOF_NOJUMP,
				maxseedist:512,
				fov:360
			);
			return;
		}
		setorigin(bbb.pos,false);
		bbb.target=target;
		if(
			random(0,31)
			||A_JumpIfInTargetLOS("null",100)
		)return;
		double dist=distance3d(target);
		if(
			hasmoved
			&&dist<random(64,1024)
		){
			bbb.A_BarrelAttack();
			return;
		}
		if(
			dist<random(512,2048)
		){
			bbb.A_BarrelMove();
			hasmoved=true;
		}
	}
	states{
	spawn:
		TNT1 A 10 A_GremlinHunt();
		wait;
	death:
		TNT1 A 1;
		stop;
	}
}

