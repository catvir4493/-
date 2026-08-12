class_name GameConfig
extends RefCounted

const GAME_TITLE := "深夜愿望便利店"
const GAME_VERSION := "0.1.0"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_BGM_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 0.8
const DEFAULT_TEXT_SPEED := 1.0
const DEFAULT_FULLSCREEN := false
const DEFAULT_SCREEN_SHAKE := true

const MIN_TEXT_SPEED := 0.5
const MAX_TEXT_SPEED := 2.0
const SETTINGS_PATH := "user://settings.json"

const MAIN_MENU_SCENE := "res://scenes/main_menu/MainMenu.tscn"
const SHOP_SCENE := "res://scenes/shop/ShopScene.tscn"
const RESULT_SCENE := "res://scenes/result/ResultScene.tscn"
const NIGHT_RESULT_SCENE := "res://scenes/night_result/NightResultScene.tscn"
const RESTOCK_SCENE := "res://scenes/restock/RestockScene.tscn"
const ARCHIVE_SCENE := "res://scenes/archive/ArchiveScene.tscn"
const SETTINGS_SCENE := "res://scenes/settings/SettingsScene.tscn"

const DEFAULT_FADE_DURATION := 0.3
