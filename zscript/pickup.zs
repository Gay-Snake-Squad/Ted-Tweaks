//-------------------------------------------------
// Pickup Archetypes
//-------------------------------------------------
class GrabThinker:Thinker{
	actor picktarget;
	actor pickobj;
	int ticker;
	bool oldsolid;
	static void Grab(actor grabber,actor grabee,int delay=0){
		let hdp=hdpickup(grabee);
		if(hdp){
			if(hdp.bisbeingpickedup)return;
			hdp.bisbeingpickedup=true;
		}

		let grabthink=new("GrabThinker");
		if(delay)grabthink.ticker=-abs(delay);
		grabthink.picktarget=grabber;
		if(grabee){
			grabthink.pickobj=grabee;
			grabthink.oldsolid=grabee.bsolid;
		}
	}
	override void ondestroy(){
		if(pickobj)pickobj.bsolid=oldsolid;
	}
	override void tick(){
		if(!picktarget||!picktarget.player||!pickobj){destroy();return;}
		super.tick();
		ticker++;
		if(ticker<0){
			return;
		}else if(ticker<4){
			pickobj.setorigin(
				0.5*(
					(picktarget.pos+(0,0,picktarget.height*0.8))
					+pickobj.pos
				),true
			);
			pickobj.bsolid=false;
		}else{
			let pt=hdpickup(pickobj);if(pt)pt.bisbeingpickedup=false;
			let mt=hdmagammo(pickobj);
			let wt=hdweapon(pickobj);
			let ht=hdupk(pickobj);
			let tt=inventory(pickobj);
			if(
				!pickobj
				||!picktarget
				||picktarget.health<1
			){
				destroy();
				return;
			}

			vector2 shiftpk=actor.rotatevector((frandom(-0.4,-0.8),frandom(0.8,1.1)),picktarget.angle);
			pickobj.vel.xy+=shiftpk;
			pickobj.setorigin((pickobj.pos.xy+shiftpk,pickobj.pos.z),true);

			if(ht){
				ht.picktarget=picktarget;
				ht.a_hdupkgive();
				destroy();
				return;
			}

			if(
				pt
				&&(
					pt.BeforePockets(picktarget)
					||pt.CheckConflictingWornLayer(picktarget)
				)
			){
				destroy();
				return;
			}


			//if backpack is out, try to move into backpack
			if(picktarget.player.readyweapon is "HDBackpack"){
				let bp=HDBackpack(picktarget.player.readyweapon);
				if(
					bp
					&&(
						bp.CanGrabInsert(tt,tt.GetClass(),picktarget)
						&&bp.Storage.TryInsertItem(tt,picktarget,tt.Amount,flags:BF_SELECT)==tt.Amount
						||!pickobj //if totally picked up, don't do the rest of the checks
					)
				){
					destroy();
					return;
				}
			}

			//check for pocket space
			let hdpt=hdplayerpawn(picktarget);
			bool maglimited=
				hdpt
				&&mt
				&&hdpt.hd_maglimit.getint()>0
				&&hdpt.countinv(mt.getclassname())>=hdpt.hd_maglimit.getint()
			;
			bool holdingfiremode=
				picktarget.player
				&&picktarget.player.cmd.buttons&BT_FIREMODE
			;
			if(
				(
					!tt
					||!tt.balwayspickup
				)&&(
					(
						pt
						&&HDPickup.MaxGive(picktarget,pt.getclass(),
							mt?mt.getbulk():pt.bulk
						)<1
					)||(
						ht
						&&ht.pickuptype!="none"
						&&HDPickup.MaxGive(picktarget,pt.getclass(),
							getdefaultbytype(ht.pickuptype).bulk
						)<1
					)||(
						mt
						&&(
							holdingfiremode
							||maglimited
						)
					)
				)
			){
				//make one last check for mag switch before aborting
				//do a single 1:1 switch with the lowest mag
				if(mt){
					name gcn=mt.getclassname();
					let alreadygot=HDMagAmmo(picktarget.findinventory(gcn));
					if(alreadygot){
						alreadygot.syncamount();
						int thismag=mt.mags[0];
						bool thisisbetter=false;
						for(int i=0;!thisisbetter&&i<alreadygot.amount;i++){
							if(thismag>alreadygot.mags[i])thisisbetter=true;
						}
						if(thisisbetter){
							alreadygot.LowestToLast();
							if(hd_debug)alreadygot.logamounts();
							picktarget.A_DropInventory(gcn,1);
							if(cvar.getcvar("hd_helptext",picktarget.player).getbool())picktarget.A_Log("Discarding inferior mag to make room.",true);
							mt.actualpickup(picktarget);
							destroy();
							return;
						}else{
							if(cvar.getcvar("hd_helptext",picktarget.player).getbool()){
								if(maglimited){
									picktarget.A_Log("hd_maglimit "..hdpt.hd_maglimit.getint().." exceeded.",true);
								}else if(holdingfiremode){
									picktarget.A_Log("Firemode held but target mag not better. Swap aborted.",true);
								}
							}
							destroy();
							return;
						}
					}
				}

				if(cvar.getcvar("hd_helptext",picktarget.player).getbool()){
					picktarget.A_Log("No room in pockets.",true);
					if(hdpt)hdpt.hasgrabbed=true;
				}
				destroy();
				return;
			}

			//handle actual pickups
			if(pt){
				pt.actualpickup(picktarget);
			}else if(wt){
				wt.actualpickup(picktarget);
			}else if(tt){
				if(picktarget.vel==(0,0,0))picktarget.A_ChangeVelocity(0.001,0,0,CVF_RELATIVE);
			}
			destroy();
			return;
		}
	}
}
class HDPickerUpper:Actor{
	default{
		+solid
		+nogravity
		+noblockmap
		+noblockmonst
		height 1;
		radius 2;
	}
	override bool cancollidewith(actor other,bool passive){
		return inventory(other)||hdupk(other);
	}
}

extend class HDPlayerPawn{
	void PickupGrabber(int putimes=-1){
		if(!hasgrabbed){
			actor grabbed=null;

			//get a pickerupper
			hdpickerupper hdpu=null;
			ThinkerIterator hdpuf=ThinkerIterator.Create("HDPickerUpper");
			while(hdpu=HDPickerUpper(hdpuf.Next())){
				if(hdpu.master==self)break;
			}
			if(!hdpu||hdpu.master!=self){
				hdpu=HDPickerUpper(spawn("HDPickerUpper",pos,ALLOW_REPLACE));
				hdpu.master=self;
			}

			double cp=cos(pitch+3);
			vector3 pudir=1.8*(cp*cos(angle),cp*sin(angle),-sin(pitch+3));
			hdpu.setorigin((pos.xy,pos.z+height-12),false);
			if(putimes<0)putimes=int(((pudir.z<0.1)?24:18)*heightmult);
			hdpu.maxstepheight=0.9*putimes;
			for(int i=0;i<putimes;i++){
				hdpu.setorigin(hdpu.pos+pudir,false);
				bool ncm=!hdpu.checkmove(hdpu.pos.xy);
				if(
					ncm
					&&!!hdpu.blockingline
					&&!hdpu.blockingmobj
				){
					if(
						(player.cmd.buttons&BT_USE)
						&&!(player.oldbuttons&BT_USE)
					){
						vel-=pudir*0.05;
						muzzleclimb1.y-=0.05;
						muzzleclimb2.y+=0.025;
						muzzleclimb3.y+=0.015;
						muzzleclimb4.y+=0.01;
					}
					pudir=(0,0,0);
				}
				if(
					ncm
					&&!!hdpu.blockingmobj
					&&abs(hdpu.pos.z-hdpu.blockingmobj.pos.z)<putimes
				){
					grabbed=hdpu.blockingmobj;

					//don't hoover the big things
					if(
						grabbed is "HDWeapon"
						||grabbed is "HDMagAmmo"
					)hasgrabbed=true;
				}
			}


			if(
				inventory(grabbed)
				||hdupk(grabbed)
			){
				//call the special right away before any other checks that risk skipping it
				A_CallSpecial(
					grabbed.special,grabbed.args[0],
					grabbed.args[1],grabbed.args[2],
					grabbed.args[3],grabbed.args[4]
				);
				grabbed.special=0;
				grabbed.changetid(0);

				//secret too
				if(grabbed.bCountSecret){
					GiveSecret(true,true);
					grabbed.bCountSecret=false;
				}
			}

			if(
				grabbed
				&&(
					hdupk(grabbed)
					||inventory(grabbed)
				)
			){
				if(
					grabbed is "hdupk"
					||grabbed is "inventory"
				){
					if(
						grabbed is "hdweapon"
						||(grabbed is "hdpickup"&&!hdpickup(grabbed).bmultipickup)
						||(grabbed is "hdupk"&&!hdupk(grabbed).bmultipickup)
					){
						hasgrabbed=true;
					}
					let hdpk=hdupk(grabbed);
					if(hdpk){
						hdpk.picktarget=self;
						if(hdpk.findstate("grab",true)){
							if(hd_debug)console.printf("Custom grab states are deprecated. Please use the OnGrab() function instead.");
							grabbed.setstatelabel("grab");
						}
						if(!hdpk.OnGrab(self))return;
					}else{
						let hdpu=hdpickup(grabbed);
						if(
							hdpu
							&&!hdpu.OnGrab(self)
						)return;
						let hdwp=hdweapon(grabbed);
						if(
							hdwp
							&&!hdwp.OnGrab(self)
						)return;
					}

					//final check for pickup process before spawning grabber
					let hdpg=hdpickup(grabbed);
					grabthinker.Grab(self,grabbed);
				}
			}
		}
	}
}



//Usable pickup.
class HDPickup:CustomInventory{
	int HDPickupFlags;
	flagdef DropTranslation:HDPickupFlags,0;
	flagdef FitsInBackpack:HDPickupFlags,1;
	flagdef MultiPickup:HDPickupFlags,2; //lets you continue picking up without re-pressing the key
	flagdef IsBeingPickedUp:HDPickupFlags,3;
	flagdef CheatNoGive:HDPickupFlags,4;
	flagdef MustShowInMagManager:HDPickupFlags,5;
	flagdef NotInPockets:HDPickupFlags,6;
	flagdef NeverShowInPickupManager:HDPickupFlags,7;
	flagdef FullCoverage:HDPickupFlags,8;
	flagdef BodyCoverage:HDPickupFlags,9;
	flagdef FaceCoverage:HDPickupFlags,10;
	flagdef NoRandomBackpackSpawn:HDPickupFlags,11;

	actor picktarget;
	double bulk;
	property bulk:bulk;
	int maxunitamount;
	property maxunitamount:maxunitamount;
	string refid;property refid:refid;  //modding note: NEVER, EVER include capitals in a refid!
	int wornlayer;property wornlayer:wornlayer;
	default{
		+solid
		+inventory.invbar +inventory.persistentpower
		+noblockmonst +notrigger +dontgib

		+hdpickup.droptranslation
		-hdpickup.multipickup
		+hdpickup.fitsinbackpack
		-hdpickup.cheatnogive
		-hdpickup.isbeingpickedup
		+hdpickup.bodycoverage

		inventory.interhubamount int.MAX;
		inventory.maxamount 1000;

		hdpickup.bulk 0;
		hdpickup.refid "";

		radius 8; height 10; scale 0.8;
		gravity HDCONST_GRAVITY;
		inventory.pickupsound "weapons/pocket";
		hdpickup.maxunitamount 1;

		hdpickup.wornlayer 0;  //for playsim
		hdpickup.overlaypriority 0;  //for hud
	}
	override bool cancollidewith(actor other,bool passive){
		return HDPickerUpper(other);
	}

	//called on level resets, etc.
	virtual void Consolidate(){}

	//when a grabber touches it but before the pull
	virtual bool OnGrab(actor grabber){return true;}

	//when the item has been taken in but just before inventory capacity is checked
	virtual bool BeforePockets(actor other){return false;}

	//called to get the encumbrance
	virtual double getbulk(){return amount*bulk;}
	override inventory createtossable(int amt){
		let onr=owner;
		inventory iii=super.createtossable(amt);
		if(bdroptranslation&&onr){
			if(iii)iii.translation=onr.translation;
		}
		return iii;
	}
	virtual double RestrictSpeed(double speedcap){return speedcap;}

	//these functions are responsible for capping a player's inventory.
	//DO NOT attempt to use anything not here!
	static double MaxPocketSpace(actor caller){
		let hdp=hdplayerpawn(caller);
		if(hdp)return hdp.maxpocketspace;
		return HDCONST_MAXPOCKETSPACE;
	}
	static double PocketSpaceTaken(actor caller){
		double pocketenc=0;
		for(inventory hdww=caller.inv;hdww!=null;hdww=hdww.inv){
			let hdp=hdpickup(hdww);
			if(
				hdp
				&&!hdp.bnotinpockets
			)pocketenc+=abs(hdp.getbulk());
		}
		return pocketenc*hdmath.getencumbrancemult();
	}
	static int MaxGive(actor caller,class<inventory> type,double unitbulk){
		unitbulk*=hdmath.getencumbrancemult();
		int absmax=getdefaultbytype(type).maxamount-caller.countinv(type);
		if(unitbulk<=0)return absmax;
		double spaceleft=HDPickup.MaxPocketSpace(caller)-HDPickup.PocketSpaceTaken(caller);
		int mg=int(clamp(absmax,0,spaceleft/unitbulk));
		if(
			mg<1
			&&absmax>0
			&&(class<hdpickup>)(type)
			&&getdefaultbytype((class<hdpickup>)(type)).bnotinpockets
			&&(
				!hdplayerpawn(caller)
				||hdplayerpawn(caller).overloaded<30.
			)
		)mg=1;
		return mg;
	}


	override void doeffect(){
		if(amount<1)destroy();
		else if(
			hdplayerpawn(owner)
			&&(
				!(level.time&(1|2|4|8|16|32|64))
				||level.time==1
			)
		){
			//remove excess items in reduced-encumbrance play
			double encumb=HDMath.GetEncumbranceMult();
			if(encumb<1){
				double gb=getbulk();
				if(gb){
					bool givemessage=false;
					int ema=int(max(1,max(70,HDCONST_MAXPOCKETSPACE*encumb)*amount*2/gb));
					int todrop=amount-ema;
					if(todrop>0){
						if(amount>(maxamount>>1)){
							amount=ema;
							if(hdmagammo(self))hdmagammo(self).mags.resize(ema);
							givemessage=true;
						}else{
							owner.A_DropInventory(getclass(),min(10,todrop));
							givemessage=level.time<=128;
						}
					}
					if(givemessage)owner.A_Log(string.format("Low-encumbrance maximum for %s is %i.",gettag(),ema),true);
				}
			}
		}
	}


		//mostly just used for the liteamp
	bool IsConsolePlayer(){
		return
			owner
			&&owner.player
			&&owner.player.mo
			&&owner.player==players[consoleplayer]
		;
	}
	void SetShader(string shaderName,bool enabled){
		if(IsConsolePlayer())PPShader.SetEnabled(shaderName,enabled);
	}
	void SetShaderU1f(string shaderName,string uniformName,float value){
		if(IsConsolePlayer())PPShader.SetUniform1f(shaderName,uniformName,value);
	}
	void SetShaderU2f(string shaderName,string uniformName,vector2 value){
		if(IsConsolePlayer())PPShader.SetUniform2f(shaderName,uniformName,value);
	}
	void SetShaderU3f(string shaderName,string uniformName,vector3 value){
		if(IsConsolePlayer())PPShader.SetUniform3f(shaderName,uniformName,value);
	}
	void SetShaderU1i(string shaderName,string uniformName,int value){
		if(IsConsolePlayer())PPShader.SetUniform1i(shaderName,uniformName,value);
	}


	//for the status bar
	virtual ui int getsbarnum(int flags=0){return -1000000;}
	virtual ui int DisplayAmount(){return amount;}
	virtual ui void DisplayOverlay(hdstatusbar sb,hdplayerpawn hpl){}
	virtual ui void DrawHudStuff(
		hdstatusbar sb,
		hdplayerpawn hpl,
		int hdflags,
		int gzflags
	){}
	override void touch(actor toucher){}
	virtual void actualpickup(actor other,bool silent=false){
		if(!other)other=picktarget;
		if(!other)return;
		if(heat.getamount(self)>50)return;
		if(balwayspickup){
			inventory.touch(other);
			return;
		}
		name gcn=getclassname();
		int maxtake=min(amount,HDPickup.MaxGive(other,gcn,getbulk()));
		if(maxtake<1)return;

		if(!silent){
			other.A_StartSound(pickupsound,CHAN_AUTO);
			HDPickup.LogPickupMessage(other,pickupmessage());
		}

		bool gotpickedup=false;
		if(maxtake<amount){
			HDF.Give(other,gcn,maxtake);
			amount-=maxtake;
			SplitPickup();
		}else{
			if(!other.findinventory(getclass()))attachtoowner(other);
			else{
				HDF.Give(other,gcn,maxtake);
				destroy();
			}
		}
	}
	int overlaypriority;
	property overlaypriority:overlaypriority;


	//allow pickup messages to use custom colour
	static void LogPickupMessage(
		actor caller,
		string pickupmessage,
		name msgcolour="msg0color"
	){
		if(pickupmessage=="")return;
		caller.A_Log(string.format("%s%s",
			HDMath.MessageColour(caller,msgcolour),
			pickupmessage
		),true);
	}


	// If two wearable classes have the same layer number, they should be
	// considered to be occupying the same place and unable to be combined.
	// If you've set up the CheckStrip() checks properly,
	// this check should never come up as true.
	bool CheckConflictingWornLayer(actor other,bool bugreport=false){
		if(!wornlayer||!other)return false;
		for(inventory iii=other.inv;iii!=null;iii=iii.inv){
			let hdp=hdpickup(iii);
			if(
				hdp
				&&hdp!=self
				&&hdp.wornlayer==wornlayer
			){
				if(bugreport)console.printf("\cgERROR: "..gettag().." wornlayer property conflicts with "..hdp.gettag()..". Please report this bug to the modder responsible.");
				return true;
			}
		}return false;
	}


	override void AttachToOwner(actor other){
		super.AttachToOwner(other);

		//in case it's added in a loadout
		if(CheckConflictingWornLayer(owner,true)){
			amount=0;
			return;
		}

		if(overlaypriority){
			let hpl=HDPlayerPawn(owner);
			if(
				hpl
				&&hpl==other
			)hpl.GetOverlayGivers(hpl.OverlayGivers);
		}
	}


	//delete once no longer needed
	void GotoSpawn(){
		if(findstate("spawn2")){
			if(hd_debug)A_Log(string.format("%s still uses spawn2",getclassname()));
			setstatelabel("spawn2");
		}
	}

	//so you don't get a bullet pickup that's 2 bullets somehow
	virtual void SplitPickup(){
		int maxpkamt=max(1,maxunitamount);
		while(amount>maxpkamt){
			let aaa=hdpickup(spawn(getclassname(),pos,ALLOW_REPLACE));
			aaa.amount=maxpkamt;amount-=maxpkamt;
			aaa.vel=vel+(frandom(-0.6,0.6),frandom(-0.6,0.6),frandom(-0.6,0.6));
			if(bdroptranslation)aaa.translation=translation;
		}
		GotoSpawn();
	}
	override void postbeginplay(){

		//don't spawn if certain dmflags
		if(
			deathmatch  //sv_noarmor/health normally does nothing outside dm
			&&(
				(sv_noarmor&&bisarmor)
				||(sv_nohealth&&bishealth)
			)
		){
			destroy();
			return;
		}

		itemsthatusethis.clear();
		GetItemsThatUseThis();

		super.postbeginplay();

		if(hdpickup.checkblacklist(self,refid))return;

		let hdps=new("HDPickupSplitter");
		hdps.invoker=self;
	}

	//parse what would normally be the amount string as a set of variables
	virtual void loadoutconfigure(string input){}

	//This is an array of item names created on an actor's initialization.
	//If you have a sub-mod item that also uses a given ammo type,
	//you can use an event handler to add that item to this array for that ammo type.
	//The IsUsed function can, of course, take in any other circumstances you can write in.
	array<string> itemsthatusethis;
	virtual void GetItemsThatUseThis(){}
	virtual bool IsUsed(){return true;}

	//destroy caller if a refid is mentioned in hd_blacklist
	static bool checkblacklist(actor caller,string refid,bool force=false){
		if(refid=="")return false;
		string bl=hd_blacklist;
		bl=bl.makelower();
		if(!force&&bl.left(3)!="all")return false;
		bl.replace(" ","");
		int bldex=bl.rightindexof(refid.makelower());
		// this must use RightIndexOf not IndexOf!
		// consider: "bfg=zrk,zrk=fis" - zerk replaced with none added
		// versus "bfg=zrk,zrk=fis,hrp=zrk" - zerk replaced, then added elsewhere
		// only if the FINAL instance of the refid does not follow "=" that it is truly blacklisted.
		if(bldex>=0){
			string prevchar=bl.mid(bldex-1,1);
			if(prevchar!="="){
				caller.destroy();
				return true;
			}
		}
		return false;
	}


	//like A_DropItem but you can set the amount
	static inventory DropItem(
		actor caller,
		class<inventory> itemtype,
		int amt,
		bool pickup=false
	){
		let mmm=inventory(
			caller.spawn(itemtype,
				(caller.pos.xy,caller.pos.z+max(0,caller.height-12)),
			ALLOW_REPLACE)
		);
		mmm.angle=caller.angle;
		mmm.A_ChangeVelocity(2,0,-1,CVF_RELATIVE);
		mmm.vel+=caller.vel;
		let mmmm=HDMagAmmo(mmm);
		if(mmmm){
			mmmm.amount=0;
			mmmm.mags.clear();
			mmmm.AddAMag(amt);
		}
		else mmm.amount=amt;
		if(pickup){
			let ppp=HDPickup(mmm);
			if(ppp)ppp.actualpickup(caller);
			else ppp.touch(caller);
		}
		return mmm;
	}

	static void SetDropVel(actor dropper,actor caller){
		caller.setz(dropper.pos.z+dropper.height*0.8);
		double dp=max(dropper.pitch-6,-90);
		caller.vel=dropper.vel+(
			cos(dp)*(cos(dropper.angle),sin(dropper.angle)),
			-sin(dp)
		)*3;
	}
	override void OnDrop(actor dropper){
		super.OnDrop(dropper);
		if(dropper)SetDropVel(dropper,self);
		HDBackpack.ForceUpdate(dropper);
	}

	states{
	use:
		TNT1 A 0;
		fail;
	spawn:
		CLIP A -1;
		stop;
	}
}
class HDPickupSplitter:Thinker{
	hdpickup invoker;
	override void Tick(){
		super.tick();
		if(!!invoker&&!invoker.owner){
			invoker.SplitPickup();
		}
		destroy();
	}
}

//custom ammotype
class HDAmmo:HDPickup{
	default{
		-inventory.invbar
		-hdpickup.droptranslation
	}
	override bool IsUsed(){
		if(!owner)return true;
		for(int i=0;i<itemsthatusethis.size();i++){
			if(owner.countinv(itemsthatusethis[i]))return true;
		}
		return false;
	}
}
class HDRoundAmmo:HDAmmo{
	void SplitPickupBoxableRound(
		int packnum,
		int boxnum,
		class<actor> boxtype,
		name packsprite,
		name singlesprite
	){
		//abort if death state - ejected shell uses this
		if(curstate==resolvestate("death"))return;

		//enter an invalid number to skip the boxes
		if(boxnum<=0)boxnum=amount+1;

		while(amount>packnum){
			if(amount>=boxnum){
				actor aaa=spawn(boxtype,pos+(frandom(-1,1),frandom(-1,1),frandom(-1,1)));
				aaa.vel=vel+(frandom(-0.6,0.6),frandom(-0.6,0.6),frandom(-0.6,0.6));
				aaa.angle=angle;
				amount-=boxnum;
			}else{
				let sss=hdpickup(spawn(getclassname(),pos+(frandom(-1,1),frandom(-1,1),frandom(-1,1))));
				sss.vel=vel+(frandom(-0.6,0.6),frandom(-0.6,0.6),frandom(-0.6,0.6));
				sss.amount=packnum;
				sss.angle=angle;
				amount-=packnum;
			}
			if(amount<1){
				destroy();
				return;
			}
		}
		if(amount==packnum)sprite=getspriteindex(packsprite);
		else super.SplitPickup();
		if(amount==1)sprite=getspriteindex(singlesprite);
	}
}




/*
 Fake pickup for creating different actors that give the same item
 hdupk.pickupsound: pickup sound
 hdupk.pickuptype: default type of inventory item it replaces
 hdupk.pickupmessage: self-explanatory
 hdupk.maxunitamount: max # of pickuptype a single unit can store
 hdupk.amount: amount in this item, if it is a container
*/
class HDUPK:HDActor{
	int HDUPKFlags;
	flagdef MultiPickup:HDUPKFlags,0;

	actor picktarget;
	class<hdpickup> pickuptype;
	string pickupmessage;
	sound pickupsound;
	int maxunitamount;
	int amount;
	property pickuptype:pickuptype;
	property pickupmessage:pickupmessage;
	property pickupsound:pickupsound;
	property maxunitamount:maxunitamount;
	property amount:amount;
	default{
		+solid
		-hdupk.multipickup
		height 8;radius 8;
		hdupk.pickupsound "weapons/pocket";//"misc/i_pkup";
		hdupk.pickupmessage "";
		hdupk.pickuptype "none";
		hdupk.maxunitamount -1;
		hdupk.amount 1;
	}
	override bool cancollidewith(actor other,bool passive){
		return HDPickerUpper(other);
	}
	override void postbeginplay(){
		super.postbeginplay();

		if(!maxunitamount)return;
		if(maxunitamount<0)maxunitamount=abs(getdefaultbytype(getclass()).amount);
		while(amount>maxunitamount){
			let a=hdupk(spawn(getclassname(),pos,ALLOW_REPLACE));
			a.amount=maxunitamount;
			amount-=maxunitamount;
			a.vel=vel+(frandom(-1,1),frandom(-1,1),frandom(-1,1));
		}
		if(amount>1){
		}else{
			amount=1;
		}
	}
	virtual bool OnGrab(actor grabber){return true;}
	virtual void A_HDUPKGive(){
		//it's not an item container
		if(pickuptype=="none"){
			target=picktarget;
			setstatelabel("give");
			if(!bdestroyed)return;
			picktarget.A_StartSound(pickupsound,5);
			if(pickupmessage!="")HDPickup.LogPickupMessage(picktarget,pickupmessage);
			return;
		}

		//if placing directly into backpack
		if(
			picktarget.player
			&&picktarget.player.readyweapon is "HDBackpack"
		){
			let bp=hdbackpack(picktarget.player.readyweapon);

			let hdpk=(class<hdpickup>)(pickuptype);
			double defunitbulk=getdefaultbytype(hdpk).bulk;
			let hdpm=(class<hdmagammo>)(pickuptype);
			if(hdpm){
				let hdpmdef=getdefaultbytype(hdpm);
				defunitbulk=max(defunitbulk,hdpmdef.magbulk+hdpmdef.roundbulk*hdpmdef.maxperunit);
			}
			int maxtake;
			defunitbulk*=hdmath.getencumbrancemult();
			if(!defunitbulk)maxtake=int.MAX;else maxtake=int((bp.Storage.MaxBulk-bp.Storage.TotalBulk)/defunitbulk);
			int increase=min(maxtake,amount);
			if(bp.CanGrabInsert(null,pickuptype,picktarget)
				&&bp.Storage.AddAmount(pickuptype,increase,flags:BF_SELECT|BF_IGNORECAP)>0){
			amount-=increase;
			if(amount<1)destroy();
			else setstatelabel("spawn");
			return;
			}
		}

		//check effective maxamount and take as appropriate
		let mt=(class<hdmagammo>)(pickuptype);
		int maxtake=min(amount,hdpickup.maxgive(
			picktarget,pickuptype,
			mt?getdefaultbytype(mt).maxperunit+getdefaultbytype(mt).roundbulk+getdefaultbytype(mt).magbulk
			:getdefaultbytype(pickuptype).bulk
		));
		let hdp=hdplayerpawn(picktarget);
		if(
			maxtake<1
			||heat.getamount(self)>50
		){
			//didn't pick any up
			setstatelabel("spawn");
			return;
		}
		picktarget.A_StartSound(pickupsound,5);
		HDPickup.LogPickupMessage(picktarget,pickupmessage);
		HDF.Give(picktarget,pickuptype,maxtake);
		amount-=maxtake;
		if(amount>0){ //only picked some up
			setstatelabel("spawn");
			return;
		}else if(pickuptype!="none")destroy();
	}
	states{
	give:
		---- A 0;
		stop;
	spawn:
		CLIP A -1;
	spawn2:
		---- A -1;
	}
}





