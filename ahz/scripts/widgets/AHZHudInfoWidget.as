﻿import gfx.io.GameDelegate;
//import skyui.widgets.WidgetBase;
import Shared.GlobalFunc;
import skyui.util.Debug;
import flash.geom.Transform;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.display.BitmapData;

class ahz.scripts.widgets.AHZHudInfoWidget extends MovieClip
{
	//Widgets
	public var AHZBottomBar_mc:MovieClip;
	public var Book_mc:MovieClip;
	public var Inventory_mc:MovieClip;
	public var content:MovieClip;
	public var Weapons_mc:MovieClip;
	
	// Public vars
	public var ToggleState:Number;


	// Options
	private var viewSideInfo:Boolean;
	private var viewEffectsInfo:Boolean;
	private var viewBottomInfo:Boolean;
	private var viewInventoryCount:Boolean;
	private var bottomAligned:Number;
	private var inventoryAligned:Number;
	private var ingredientWidgetStyle:Number;// 1, 2, 3
	private var effectsWidgetStyle:Number;// 1, 2, 3
	private var showBackgroundForEffects:Boolean;
	private var showBackgroundForIngredients:Boolean;
	private var showBooksRead:Boolean;
	private var showWeightClass:Boolean;
	private var showBookSkill:Boolean;
	private var activationMode:Number;
	private var showTargetWeight:Boolean;

	// private variables
	private var savedRolloverInfoText:String;

	private var _mcLoader:MovieClipLoader;
	private var alphaTimer:Number;

	// Rects
	private var maxXY:Object;
	private var minXY:Object;

	// Statics
	private static var hooksInstalled:Boolean = false;

	/* INITIALIZATION */

	public function AHZHudInfoWidget()
	{
		super();

		// Get the rec of the parent
		maxXY = {x:Stage.visibleRect.x,y:Stage.visibleRect.y};
		minXY = {x:Stage.visibleRect.x + Stage.visibleRect.width,y:Stage.visibleRect.y + Stage.visibleRect.height};
		this._parent.globalToLocal(maxXY);
		this._parent.globalToLocal(minXY);

		// Anchor this widget to the top left corner
		this._y = maxXY.y;
		this._x = maxXY.x;

		// Start with the widgets hidden
		hideInventoryWidget();
		hideSideWidget();
		hideBottomWidget();
		hideInventoryWidget();
		Book_mc._alpha = 0;

		if (! hooksInstalled)
		{
			// Apply hooks to hook events
			hookFunction(_root.HUDMovieBaseInstance,"SetCrosshairTarget",this,"SetCrosshairTarget");
			hookFunction(_root.HUDMovieBaseInstance,"ShowElements",this,"ShowElements");
			_global.skse.plugins.AHZmoreHUDPlugin.InstallHooks();
			hooksInstalled = true;
		}

		// Initialize variables
		viewSideInfo = false;
		viewEffectsInfo = false;
		viewBottomInfo = false;
		viewInventoryCount = false;
		bottomAligned = 1;
		inventoryAligned = 0;
		ingredientWidgetStyle = 0;
		effectsWidgetStyle = 0;
		showBackgroundForEffects = false;
		showBackgroundForIngredients = false;
		showBooksRead = false;
		showWeightClass = false;
		showBookSkill = false;
		activationMode = 0;
		ToggleState = 0;
		savedRolloverInfoText = "";
		showTargetWeight = false;
		
		
		Weapons_mc.LeftItem.EquipIcon.gotoAndStop("LeftEquip");
		Weapons_mc.RightItem.EquipIcon.gotoAndStop("RightEquip");
		Weapons_mc.PowerItem.EquipIcon.gotoAndStop("Equipped");
	}

	function ShowElements(aMode:String,abShow:Boolean):Void
	{
		/*hudModes[0] = "All"
		hudModes[1] = "StealthMode"
		hudModes[2] = "Favor"
		hudModes[3] = "Swimming"
		hudModes[4] = "HorseMode"
		hudModes[5] = "WarHorseMode"*/

		if (aMode == "BookMode")
		{
			// Leaving book mode
			if (! abShow)
			{
				ProcessReadBook(_global.skse.plugins.AHZmoreHUDPlugin.GetIsValidTarget());
			}
		}

		var hudmode:String = _root.HUDMovieBaseInstance.HUDModes[_root.HUDMovieBaseInstance.HUDModes.length - 1];
		
		if (hudmode == "All" ||
			hudmode == "StealthMode" || 
			hudmode == "Favor" || 
			hudmode == "Swimming" || 
			hudmode == "HorseMode" || 
			hudmode == "WarHorseMode")
		{
			this._visible = true;
		}
		else
		{
			this._visible = false;
		}

	}

	public function checkForClearedHud():Void
	{
		clearInterval(alphaTimer);
		if (_root.HUDMovieBaseInstance.RolloverText._alpha < 50)
		{
			hideSideWidget();	
			hideInventoryWidget();
			Book_mc._alpha = 0;
			
			if (ToggleState == 0)
			{
				hideBottomWidget();
			}
			else
			{
				ProcessPlayerWidget(false);
			}
		}
	}

	function RefreshWidgets():Void
	{
		if (ToggleState > 0)
		{
			var validTarget:Boolean = _global.skse.plugins.AHZmoreHUDPlugin.GetIsValidTarget();
			var hudIsVisible:Boolean = (_root.HUDMovieBaseInstance.RolloverText._alpha > 0);	
			ProcessPlayerWidget(validTarget && hudIsVisible);
			ProcessTargetWidget(validTarget && hudIsVisible);
			ProcessInventoryCountWidget(validTarget && hudIsVisible);
		}
	}

	function TurnOnWidgets():Void
	{
		ToggleState = 1;
		var validTarget:Boolean = _global.skse.plugins.AHZmoreHUDPlugin.GetIsValidTarget();
		var hudIsVisible:Boolean = (_root.HUDMovieBaseInstance.RolloverText._alpha > 0);
		ProcessPlayerWidget(validTarget && hudIsVisible);
		ProcessTargetWidget(validTarget && hudIsVisible);
		ProcessInventoryCountWidget(validTarget && hudIsVisible);
	}

	function TurnOffWidgets():Void
	{
		ToggleState = 0;
		ProcessPlayerWidget(false);
		ProcessTargetWidget(false);
		ProcessInventoryCountWidget(false);
		hideBottomWidget();
	}

	// Hooks the main huds function
	function SetCrosshairTarget(abActivate:Boolean,aName:String,abShowButton:Boolean,abTextOnly:Boolean,abFavorMode:Boolean,abShowCrosshair:Boolean,aWeight:Number,aCost:Number,aFieldValue:Number,aFieldText):Void
	{
		var validTarget:Boolean = false;
		var activateWidgets:Boolean = false;
		showEquippedWidget(1);
		if (abActivate)
		{
			validTarget = _global.skse.plugins.AHZmoreHUDPlugin.GetIsValidTarget();
			if (alphaTimer != null)
			{
				clearInterval(alphaTimer);
			}
			// Set an interval to disable hide the widgets.  This is for less intrusive hud 
			alphaTimer = setInterval(this,"checkForClearedHud",6000);	
		}
		
		if ((abActivate && activationMode == 0) ||
			(abActivate && activationMode == 1 && ! _global.skse.plugins.AHZmoreHUDPlugin.GetIsPlayerInCombat()) ||
			(abActivate && activationMode == 2 && ToggleState == 1))
		{
			activateWidgets = true;
		}

		// Process the bottom player widget
		ProcessPlayerWidget(validTarget && activateWidgets);
		ProcessTargetWidget(validTarget && activateWidgets);
		ProcessInventoryCountWidget(validTarget && activateWidgets);
		
		// Always show regardless of activation mode
		ProcessBookSkill(validTarget);
		ProcessWeightClass(validTarget);
		ProcessReadBook(validTarget);
	}

	function ProcessWeightClass(isValidTarget:Boolean):Void
	{
		if (showWeightClass && isValidTarget)
		{
			// Show weight class if its armor
			if (_root.HUDMovieBaseInstance.RolloverInfoText._alpha > 0 && _root.HUDMovieBaseInstance.RolloverInfoText.htmlText != "")
			{
				var weightClass:String = _global.skse.plugins.AHZmoreHUDPlugin.GetArmorWeightClassString();
				if (weightClass != "")
				{
					// Insert the weight class into the rolloverinfo textfield
					var stringIndex:Number;
					var rolloverText:String = _root.HUDMovieBaseInstance.RolloverInfoText.htmlText;
					stringIndex = rolloverText.lastIndexOf("</P></TEXTFORMAT>");
					var firstText:String = rolloverText.substr(0,stringIndex);
					var secondText:String = rolloverText.substr(stringIndex,rolloverText.length - stringIndex);
					var formattedText = weightClass.toUpperCase();
					_root.HUDMovieBaseInstance.RolloverInfoText.htmlText = firstText + formattedText + secondText;
				}
			}
		}
	}

	function ProcessBookSkill(isValidTarget:Boolean):Void
	{
		if (showBookSkill && isValidTarget)
		{			
			// Show book skill
			if (_root.HUDMovieBaseInstance.RolloverInfoText._alpha > 0 && _root.HUDMovieBaseInstance.RolloverInfoText.htmlText != "")
			{
				var bookSkill:String = _global.skse.plugins.AHZmoreHUDPlugin.GetBookSkillString();
				if (bookSkill != "")
				{
					// Insert the weight class into the rolloverinfo textfield
					var stringIndex:Number;
					var rolloverText:String = _root.HUDMovieBaseInstance.RolloverInfoText.htmlText;
					savedRolloverInfoText = rolloverText;
					stringIndex = rolloverText.lastIndexOf("</P></TEXTFORMAT>");
					var firstText:String = rolloverText.substr(0,stringIndex);
					var secondText:String = rolloverText.substr(stringIndex,rolloverText.length - stringIndex);
					var formattedText = bookSkill.toUpperCase();
					_root.HUDMovieBaseInstance.RolloverInfoText.htmlText = firstText + formattedText + secondText;
				}
				else
				{
					savedRolloverInfoText = "";
				}
			}
			else
			{
				savedRolloverInfoText = "";
			}
		}
		else
		{
			savedRolloverInfoText = "";
		}
	}

	function ProcessTargetWidget(isValidTarget:Boolean):Void
	{
		var sideWidgetDataExists:Boolean = false;

		if (isValidTarget)
		{
			if (viewEffectsInfo)
			{
				var effectData:Object = {effectsObj:Object};
				// Get the target effects
				_global.skse.plugins.AHZmoreHUDPlugin.GetTargetEffects(effectData);

				// If effects exist
				if (effectData.effectsObj != undefined && effectData.effectsObj != null)
				{
					sideWidgetDataExists = true;
					showSideWidget(effectData.effectsObj);
				}
			}
			
			if (viewSideInfo && !sideWidgetDataExists)
			{
				var ingredientData:Object = {ingredientObj:Object};
				_global.skse.plugins.AHZmoreHUDPlugin.GetIngredientData(ingredientData);

				// If the target is an ingredient
				if (ingredientData.ingredientObj != undefined && ingredientData.ingredientObj != null)
				{
					sideWidgetDataExists = true;
					showSideWidget(ingredientData.ingredientObj);
				}
			}
		}

		// If There is no side widget data, then make sure the widget is hidden
		if (! sideWidgetDataExists)
		{
			hideSideWidget();
		}
	}

	function ProcessInventoryCountWidget(isValidTarget:Boolean):Void
	{
		if (viewInventoryCount && isValidTarget)
		{
			var inventoryData:Object = {dataObj:Object};
			_global.skse.plugins.AHZmoreHUDPlugin.GetTargetInventoryCount(inventoryData);

			if (inventoryData.dataObj == undefined || inventoryData.dataObj == null)
			{
				hideInventoryWidget();
			}
			else
			{
				showInventoryWidget(inventoryData.dataObj.inventoryName,inventoryData.dataObj.inventoryCount);
			}
		}
		else
		{
			hideInventoryWidget();
		}
	}

	function ProcessPlayerWidget(isValidTarget:Boolean):Void
	{
		if (viewBottomInfo)
		{
			var targetData:Object = {targetObj:Object};
			var playerData:Object = {playerObj:Object};

			if (isValidTarget)
			{
				// Get player data against the current target
				_global.skse.plugins.AHZmoreHUDPlugin.GetTargetObjectData(targetData);
				_global.skse.plugins.AHZmoreHUDPlugin.GetPlayerData(playerData);

				if (targetData.targetObj != undefined && targetData.targetObj != null && playerData.playerObj != undefined && playerData.playerObj != null)
				{
					// SHow the bottom widget data.  TODO: pass the object directly
					showBottomWidget(targetData.targetObj.ratingOrDamage,targetData.targetObj.difference,playerData.playerObj.encumbranceNumber,playerData.playerObj.maxEncumbranceNumber,playerData.playerObj.goldNumber,targetData.targetObj.objWeight,targetData.targetObj.formType);
				}
				else
				{
					hideBottomWidget();
				}
			}
			else if (ToggleState > 0)
			{
				// Only show player data
				_global.skse.plugins.AHZmoreHUDPlugin.GetPlayerData(playerData);
				if (playerData.playerObj != undefined && playerData.playerObj != null)
				{
					showBottomWidget(0,0,playerData.playerObj.encumbranceNumber,playerData.playerObj.maxEncumbranceNumber,playerData.playerObj.goldNumber,0.0,AHZInventoryDefines.kNone);
				}
				else
				{
					hideBottomWidget();
				}
			}
			else
			{
				hideBottomWidget();
			}
		}
		else
		{
			hideBottomWidget();
		}
	}

	// @override WidgetBase
	public function onLoad():Void
	{
		super.onLoad();
	}

	// @override MovieClipLoader
	public function onLoadInit(a_icon:MovieClip):Void
	{
	}

	// @override MovieClipLoader
	public function onLoadError(a_icon:MovieClip,a_errorCode:String):Void
	{
		// TODO
		//skse.SendModEvent("SKIWF_widgetError", "IconLoadFailure", Number(_widgetID)); //"WidgetID: " + _widgetID + " IconLoadError: " + a_errorCode + " (" + _iconSource + ")");

	}

	/* PAPYRUS INTERFACE */
	// @Papyrus
	public function showEquippedWidget(showPowerOnly:Number):Void
	{		
		setEquippedWidgetPosition(0,50.0);
		Weapons_mc._alpha = 100;
	}		
	
	public function setEquippedWidgetPosition(xPercent:Number,yPercent:Number):Void
	{
		var tempVar:Number;
		var inverse:Number;

		inverse = 1.0/(xPercent/100.0);

		tempVar = (Stage.visibleRect.width/inverse)-(300.0/inverse);
		Weapons_mc._x = tempVar;

		inverse = 1.0/(yPercent/100.0);
		tempVar = (Stage.visibleRect.height/inverse)-(Weapons_mc._height/inverse);
		Weapons_mc._y = tempVar;
	}	
	
	// @Papyrus
	public function setBottomWidgetPosition(xPercent:Number,yPercent:Number):Void
	{
		var tempVar:Number;
		var inverse:Number;

		inverse = 1.0/(xPercent/100.0);

		tempVar = (Stage.visibleRect.width/inverse)-(451.0/inverse);
		AHZBottomBar_mc._x = tempVar;

		inverse = 1.0/(yPercent/100.0);
		tempVar = (Stage.visibleRect.height/inverse)-(AHZBottomBar_mc._height/inverse);
		AHZBottomBar_mc._y = tempVar;
	}

	// @Papyrus
	public function setInventoryWidgetPosition(xPercent:Number,yPercent:Number):Void
	{
		var tempVar:Number;
		var inverse:Number;

		inverse = 1.0/(xPercent/100.0);

		tempVar = (Stage.visibleRect.width/inverse)-(381.0/inverse);
		Inventory_mc._x = tempVar;

		inverse = 1.0/(yPercent/100.0);
		tempVar = (Stage.visibleRect.height/inverse)-(Inventory_mc._height/inverse);
		Inventory_mc._y = tempVar;
	}
	
	// @Papyrus
	public function setSideWidgetPosition(xPercent:Number,yPercent:Number):Void
	{
		var tempVar:Number;
		var inverse:Number;

		inverse = 1.0/(xPercent/100.0);

		tempVar = (Stage.visibleRect.width/inverse)-(content.SizeHolder_mc._width/inverse);
		content._x = tempVar;

		inverse = 1.0/(yPercent/100.0);
		tempVar = (Stage.visibleRect.height/inverse)-(content.SizeHolder_mc._height/inverse);
		content._y = tempVar;
	}

	// @Papyrus
	public function updateSettings(sideView:Number, 
								   effectsView:Number, 
								   bottomView:Number, 
								   inventoryCount:Number, 
								   bottomAlignedValue:Number, 
								   inventoryAlignedValue:Number, 
								   ingredientWidgetStyleValue:Number, 
								   effectsWidgetStyleValue:Number,
								   showWeightClassValue:Number,
								   showBooksReadValue:Number,
								   activationModeValue:Number,
								   ToggleStateValue:Number,
								   showBookSkillValue:Number,
								   showTargetWeightValue:Number):Void {
		
		viewSideInfo = (sideView>=1);
		viewBottomInfo = (bottomView>=1);
		viewInventoryCount = (inventoryCount>=1);
		bottomAligned = bottomAlignedValue;
		inventoryAligned = inventoryAlignedValue;
		viewEffectsInfo = (effectsView>=1);
		effectsWidgetStyle = effectsWidgetStyleValue;
		ingredientWidgetStyle = ingredientWidgetStyleValue;
		showBooksRead = (showBooksReadValue>=1);
		showWeightClass = (showWeightClassValue>=1);
		ToggleState = ToggleStateValue;
		activationMode = activationModeValue;
		showBookSkill = (showBookSkillValue>=1);
		showTargetWeight = (showTargetWeightValue>=1);
		
		RefreshWidgets();
	}

	// @Papyrus
	public function showBottomWidget(ratingOrDamage:Number,difference:Number,encumbranceNumber:Number,maxEncumbranceNumber:Number,goldNumber:Number,weightValue:Number,formType:Number):Void
	{
		if (viewBottomInfo)
		{
			var tempType:Number;
			if (formType == AHZInventoryDefines.kWeapon || formType == AHZInventoryDefines.kAmmo)
			{
				tempType = AHZInventoryDefines.ICT_WEAPON;
			}
			else if (formType == AHZInventoryDefines.kArmor)
			{
				tempType = AHZInventoryDefines.ICT_ARMOR;
			}
			else
			{
				tempType = AHZInventoryDefines.ICT_DEFAULT;
			}
			
			// Set to 0 to disable
			if (!showTargetWeight)
			{
				weightValue = 0;
			}
			
			AHZBottomBar_mc.UpdatePlayerInfo({damage:ratingOrDamage,armor:ratingOrDamage,gold:goldNumber,encumbrance:encumbranceNumber,maxEncumbrance:maxEncumbranceNumber},{type:tempType,damageChange:difference,armorChange:difference,objWeight:weightValue},bottomAligned);


			AHZBottomBar_mc._alpha = 100;
		}
		else
		{
			AHZBottomBar_mc._alpha = 0;
		}
	}

	// @Papyrus
	public function hideBottomWidget():Void
	{
		AHZBottomBar_mc._alpha = 0;
	}

	// @Papyrus
	public function hideSideWidget():Void
	{
		content.gotoAndStop("DEFAULT");
	}

	public function hideInventoryWidget():Void
	{
		Inventory_mc._alpha = 0;
	}

	public function showInventoryWidget(inventoryName:String,inventoryCount:Number)
	{
		if (viewInventoryCount && inventoryCount > 0)
		{
			Inventory_mc.InventoryCount.SetText(inventoryCount.toString());
			Inventory_mc.InventoryName.SetText(inventoryName);

			if (inventoryAligned == 1)
			{
				// Right Aligned
				Inventory_mc.InventoryCount.autoSize = "right";
				Inventory_mc.InventoryName.autoSize = "right";

				Inventory_mc.InventoryCount._x = 381.0 - Inventory_mc.InventoryCount._width;
				Inventory_mc.InventoryName._x = Inventory_mc.InventoryCount._x + Inventory_mc.InventoryCount.getLineMetrics(0).x - Inventory_mc.InventoryName._width;
			}
			else if (inventoryAligned == 2)
			{
				// Center aligned
				Inventory_mc.InventoryCount.autoSize = "right";
				Inventory_mc.InventoryName.autoSize = "right";
				Inventory_mc.InventoryCount._x = 381.0 - Inventory_mc.InventoryCount._width;
				Inventory_mc.InventoryName._x = Inventory_mc.InventoryCount._x + Inventory_mc.InventoryCount.getLineMetrics(0).x - Inventory_mc.InventoryName._width;

				// Calculate the amount to move to adjust to the center of the Inventory_mc movie clip
				var deltaVal:Number = ((381.0 - Inventory_mc.InventoryName._x) / 2.0) + Inventory_mc.InventoryName._x;
				deltaVal -= (381.0 / 2.0);

				// Shift into position
				Inventory_mc.InventoryName._x-=deltaVal;
				Inventory_mc.InventoryCount._x-=deltaVal;

			}
			else
			{
				//Default left
				Inventory_mc.InventoryCount.autoSize="left";
				Inventory_mc.InventoryName.autoSize="left";

				Inventory_mc.InventoryName._x=0;
				Inventory_mc.InventoryCount._x=Inventory_mc.InventoryName._x+Inventory_mc.InventoryName.getLineMetrics(0).width+8;
			}

			Inventory_mc._alpha=100;
		}
		else
		{
			hideInventoryWidget();
		}
	}

	// @Papyrus
	public function showSideWidget(a_val:Object):Void
	{
		if (viewEffectsInfo&&a_val.effectsDescription!=undefined&&a_val.effectsDescription!=null&&a_val.effectsDescription!="")
		{

			switch (effectsWidgetStyle)
			{
				case 0 :
					content.gotoAndStop("ST1_EFFECTS");
					break;
				case 1 :
					content.gotoAndStop("ST2_EFFECTS");
					break;
				case 2 :
					content.gotoAndStop("ST2_EFFECTS_BG");
					break;
				case 3 :
					content.gotoAndStop("ST3_EFFECTS");
					break;
				default :
					content.gotoAndStop("DEFAULT");
					break;
			}
			content.ApparelEnchantedLabel.html=true;
			content.ApparelEnchantedLabel.textAutoSize="shrink";
			content.ApparelEnchantedLabel.htmlText=a_val.effectsDescription;


			var num:Number = (content.ApparelEnchantedLabel.getLineMetrics(0).height*1.0);
			num = num*(content.ApparelEnchantedLabel.numLines);
			num = (content.ApparelEnchantedLabel._height*0.5)-(num*0.5);
			content.ApparelEnchantedLabel._y = (num-(3.0));
		} else if (viewSideInfo && a_val.effect1 != undefined && a_val.effect2 != undefined && a_val.effect3 != undefined && a_val.effect4 != undefined && a_val.effect1 != null && a_val.effect2 != null && a_val.effect3 != null && a_val.effect4 != null) {
			switch (ingredientWidgetStyle) {
				case 0 :
					content.gotoAndStop("ST1_INGREDIENTS");
					break;
				case 1 :
					content.gotoAndStop("ST2_INGREDIENTS");
					break;
				case 2 :
					content.gotoAndStop("ST2_INGREDIENTS_BG");
					break;
				case 3 :
					content.gotoAndStop("ST3_INGREDIENTS");
					break;
				default :
					content.gotoAndStop("DEFAULT");
					break;
			}

			content.Ingredient1.html=true;
			content.Ingredient2.html=true;
			content.Ingredient3.html=true;
			content.Ingredient4.html=true;

			if (a_val.effect1=="")
			{
				content.Ingredient1.htmlText="$UNKNOWN";
				content.IngredientBullet1._alpha=25;
				content.Ingredient1._alpha=25;
			}
			else
			{
				content.Ingredient1._alpha=100;
				content.IngredientBullet1._alpha=100;
				content.Ingredient1.htmlText=a_val.effect1;//.toUpperCase();
			}

			if (a_val.effect2=="")
			{
				content.Ingredient2.htmlText="$UNKNOWN";
				content.IngredientBullet2._alpha=25;
				content.Ingredient2._alpha=25;
			}
			else
			{
				content.Ingredient2._alpha=100;
				content.IngredientBullet2._alpha=100;
				content.Ingredient2.htmlText=a_val.effect2;//.toUpperCase();
			}

			if (a_val.effect3=="")
			{
				content.Ingredient3.htmlText="$UNKNOWN";
				content.IngredientBullet3._alpha=25;
				content.Ingredient3._alpha=25;
			}
			else
			{
				content.Ingredient3._alpha=100;
				content.IngredientBullet3._alpha=100;
				content.Ingredient3.htmlText=a_val.effect3;//.toUpperCase();
			}

			if (a_val.effect4=="")
			{
				content.Ingredient4.htmlText="$UNKNOWN";
				content.IngredientBullet4._alpha=25;
				content.Ingredient4._alpha=25;
			}
			else
			{
				content.Ingredient4._alpha=100;
				content.IngredientBullet4._alpha=100;
				content.Ingredient4.htmlText=a_val.effect4;//.toUpperCase();
			}
		}
		else
		{
			content.gotoAndStop("DEFAULT");
		}
	}

	public function ProcessReadBook(isValidTarget:Boolean):Void
	{
		if (showBooksRead&&isValidTarget)
		{
			var bookRead:Boolean=_global.skse.plugins.AHZmoreHUDPlugin.GetIsBookAndWasRead();

			if (bookRead&&_root.HUDMovieBaseInstance.RolloverInfoText._alpha>0&&_root.HUDMovieBaseInstance.RolloverInfoText.htmlText!="")
			{
				// Restore the RolloverInfoText if this was a skill book that was read
				if (savedRolloverInfoText != "")
				{
					_root.HUDMovieBaseInstance.RolloverInfoText.htmlText = savedRolloverInfoText;
				}				
				// Remove the right margin if it already exists
				var formatText:String=_root.HUDMovieBaseInstance.RolloverInfoText.htmlText;
				var tempArray:Array=formatText.split("RIGHTMARGIN=\"60\"");
				formatText=tempArray.join("RIGHTMARGIN=\"0\"");
				_root.HUDMovieBaseInstance.RolloverInfoText.htmlText=formatText;

				// Get the coordinates for the rollover textfield
				var theX:Number = 	
				_root.HUDMovieBaseInstance._x + 
				_root.HUDMovieBaseInstance.RolloverInfoText._x + 
				_root.HUDMovieBaseInstance.RolloverInfoText.getLineMetrics(0).x +
				_root.HUDMovieBaseInstance.RolloverInfoText.getLineMetrics(0).width;
				var theY:Number = _root.HUDMovieBaseInstance._y + _root.HUDMovieBaseInstance.RolloverInfoText._y;
				theY = theY + 7.0;
				

				// Convert to this coordinates
				var myPoint:Object={x:theX,y:theY};
				this.globalToLocal(myPoint);
				Book_mc._x=myPoint.x;
				Book_mc._y=myPoint.y;
				Book_mc._alpha=75;

				// Add a right margin to the rollover textfield to give room for the read image
				var formatText:String=_root.HUDMovieBaseInstance.RolloverInfoText.htmlText;
				var tempArray:Array=formatText.split("RIGHTMARGIN=\"0\"");
				formatText=tempArray.join("RIGHTMARGIN=\"60\"");
				_root.HUDMovieBaseInstance.RolloverInfoText.htmlText=formatText;
			}
			else
			{
				Book_mc._alpha=0;
			}
		}
		else
		{
			Book_mc._alpha=0;
		}
	}

	public function log(txt:String):Void
	{
	}

//hookFunction(_root.HUDMovieBaseInstance,"SetCrosshairTarget",this,"SetCrosshairTarget");
	public static function hookFunction(a_scope:Object, a_memberFn:String, a_hookScope:Object, a_hookFn:String):Boolean {
		var memberFn:Function = a_scope[a_memberFn];
		if (memberFn == null || a_scope[a_memberFn] == null) {
			return false;
		}

		a_scope[a_memberFn] = function () {
			memberFn.apply(a_scope,arguments);
			a_hookScope[a_hookFn].apply(a_hookScope,arguments);
		};
		return true;
	}
}