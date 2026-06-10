import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const bool _mockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: false);

class LocalDb {
  static Database? _db;
  static const String _dbName = 'balneario_comboriu.db';
  static const int _dbVersion = 9;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    
    Future<void> onUpgradeDb(Database db, int oldVersion, int newVersion) async {
      if (oldVersion < 2) {
        await db.execute('CREATE TABLE IF NOT EXISTS autos_sanitarios (id INTEGER PRIMARY KEY, tipo_auto TEXT, numero_auto TEXT, estabelecimento_id INTEGER, fiscal_id INTEGER, data TEXT, descricao TEXT, fundamentacao_legal TEXT, observacoes TEXT, status TEXT)');
      }
      if (oldVersion < 3) {
        final columns = ['cnae', 'rua', 'numero', 'bairro', 'cep', 'cidade', 'telefone', 'email', 'responsavel', 'cpf_responsavel', 'risco', 'status_alvara'];
        for (var col in columns) {
          try { await db.execute('ALTER TABLE estabelecimentos ADD COLUMN $col TEXT'); } catch (_) {}
        }
      }
      if (oldVersion < 4) {
        await db.execute('CREATE TABLE IF NOT EXISTS itens_inspecao (id INTEGER PRIMARY KEY, inspecao_id INTEGER, item TEXT, status TEXT, observacao TEXT)');
      }
      if (oldVersion < 5) {
        try { await db.execute('ALTER TABLE estabelecimentos ADD COLUMN lat REAL'); } catch (_) {}
        try { await db.execute('ALTER TABLE estabelecimentos ADD COLUMN lng REAL'); } catch (_) {}
      }
      if (oldVersion < 6) {
        final columns = ['atividade_principal', 'status_sanitario', 'grau_risco', 'data_cadastro', 'uf'];
        for (var col in columns) {
          try { await db.execute('ALTER TABLE estabelecimentos ADD COLUMN $col TEXT'); } catch (_) {}
        }
      }
      if (oldVersion < 7) {
        final autosColumns = <String, String>{
          'inspecao_id': 'INTEGER',
          'responsavel_nome': 'TEXT',
          'responsavel_cpf': 'TEXT',
          'responsavel_cargo': 'TEXT',
          'responsavel_telefone': 'TEXT',
          'fiscal_nome': 'TEXT',
          'fiscal_matricula': 'TEXT',
          'data_inspecao': 'TEXT',
          'hora_inspecao': 'TEXT',
          'tipo_inspecao': 'TEXT',
          'classificacao_infracao': 'TEXT',
          'apreensao': 'INTEGER',
          'interdicao': 'INTEGER',
          'tipo_medida': 'TEXT',
          'prazo_regularizacao': 'INTEGER',
          'valor_multa': 'REAL',
          'latitude': 'REAL',
          'longitude': 'REAL',
          'endereco_gps': 'TEXT',
          'pdf_local': 'TEXT',
        };
        for (final entry in autosColumns.entries) {
          try { await db.execute('ALTER TABLE autos_sanitarios ADD COLUMN ${entry.key} ${entry.value}'); } catch (_) {}
        }

        final fotosColumns = <String, String>{
          'auto_id': 'INTEGER',
          'descricao': 'TEXT',
          'categoria': 'TEXT',
        };
        for (final entry in fotosColumns.entries) {
          try { await db.execute('ALTER TABLE fotos ADD COLUMN ${entry.key} ${entry.value}'); } catch (_) {}
        }
      }
      if (oldVersion < 8) {
        final autosColumns = <String, String>{
          'ano': 'TEXT',
          'data_hora': 'TEXT',
          'tipo_documento': 'TEXT',
          'responsavel_tecnico_id': 'TEXT',
          'profissional_id': 'TEXT',
          'testemunha_1': 'TEXT',
          'testemunha_2': 'TEXT',
          'dados_estabelecimento': 'TEXT',
          'base_legal_json': 'TEXT',
          'descricao_json': 'TEXT',
          'auto_intimacao_json': 'TEXT',
          'auto_infracao_json': 'TEXT',
          'imposicao_penalidade_json': 'TEXT',
          'auto_coleta_amostra_json': 'TEXT',
          'inspecao_sanitaria_json': 'TEXT',
          'profissionais_equipe_json': 'TEXT',
          'payload_json': 'TEXT',
          'data_documento': 'TEXT',
          'profissional_nome': 'TEXT',
          'estabelecimento_nome': 'TEXT',
          'estabelecimento_cnpj': 'TEXT',
          'numero_ano': 'TEXT',
          'status_sincronizacao': 'TEXT',
        };
        for (final entry in autosColumns.entries) {
          try { await db.execute('ALTER TABLE autos_sanitarios ADD COLUMN ${entry.key} ${entry.value}'); } catch (_) {}
        }
      }
      if (oldVersion < 9) {
        final autosColumns = <String, String>{
          'inspecao_id': 'INTEGER',
          'responsavel_nome': 'TEXT',
          'responsavel_cpf': 'TEXT',
          'responsavel_cargo': 'TEXT',
          'responsavel_telefone': 'TEXT',
          'fiscal_nome': 'TEXT',
          'fiscal_matricula': 'TEXT',
          'data_inspecao': 'TEXT',
          'hora_inspecao': 'TEXT',
          'tipo_inspecao': 'TEXT',
          'classificacao_infracao': 'TEXT',
          'apreensao': 'INTEGER',
          'interdicao': 'INTEGER',
          'tipo_medida': 'TEXT',
          'prazo_regularizacao': 'INTEGER',
          'valor_multa': 'REAL',
          'latitude': 'REAL',
          'longitude': 'REAL',
          'endereco_gps': 'TEXT',
          'pdf_local': 'TEXT',
          'ano': 'TEXT',
          'data_hora': 'TEXT',
          'tipo_documento': 'TEXT',
          'responsavel_tecnico_id': 'TEXT',
          'profissional_id': 'TEXT',
          'testemunha_1': 'TEXT',
          'testemunha_2': 'TEXT',
          'dados_estabelecimento': 'TEXT',
          'base_legal_json': 'TEXT',
          'descricao_json': 'TEXT',
          'auto_intimacao_json': 'TEXT',
          'auto_infracao_json': 'TEXT',
          'imposicao_penalidade_json': 'TEXT',
          'auto_coleta_amostra_json': 'TEXT',
          'inspecao_sanitaria_json': 'TEXT',
          'profissionais_equipe_json': 'TEXT',
          'payload_json': 'TEXT',
          'data_documento': 'TEXT',
          'profissional_nome': 'TEXT',
          'estabelecimento_nome': 'TEXT',
          'estabelecimento_cnpj': 'TEXT',
          'numero_ano': 'TEXT',
          'status_sincronizacao': 'TEXT',
        };
        for (final entry in autosColumns.entries) {
          try { await db.execute('ALTER TABLE autos_sanitarios ADD COLUMN ${entry.key} ${entry.value}'); } catch (_) {}
        }
      }
    }

    Future<void> onCreateDb(Database db, int version) async {
      await db.execute('CREATE TABLE IF NOT EXISTS estabelecimentos (id INTEGER PRIMARY KEY, cnpj TEXT, razao_social TEXT, nome_fantasia TEXT, cnae TEXT, rua TEXT, numero TEXT, bairro TEXT, cep TEXT, cidade TEXT, telefone TEXT, email TEXT, responsavel TEXT, cpf_responsavel TEXT, risco TEXT, status_alvara TEXT, lat REAL, lng REAL, atividade_principal TEXT, status_sanitario TEXT, grau_risco TEXT, data_cadastro TEXT, uf TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS inspecoes (id INTEGER PRIMARY KEY, tipo_auto TEXT, estabelecimento_id INTEGER, data TEXT, hora TEXT, status TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS fotos (id INTEGER PRIMARY KEY, inspecao_id INTEGER, url TEXT, data TEXT, gps TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS penalidades (id INTEGER PRIMARY KEY, descricao TEXT, codigo_legal TEXT, valor REAL)');
      await db.execute('CREATE TABLE IF NOT EXISTS autos_sanitarios (id INTEGER PRIMARY KEY, tipo_auto TEXT, numero_auto TEXT, estabelecimento_id INTEGER, fiscal_id INTEGER, data TEXT, descricao TEXT, fundamentacao_legal TEXT, observacoes TEXT, status TEXT)');
      await db.execute('CREATE TABLE IF NOT EXISTS itens_inspecao (id INTEGER PRIMARY KEY, inspecao_id INTEGER, item TEXT, status TEXT, observacao TEXT)');
      await onUpgradeDb(db, 1, version);
    }

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      _db = await openDatabase(_dbName, version: _dbVersion, onCreate: onCreateDb, onUpgrade: onUpgradeDb);
      await _seedIfNeeded(_db!);
      return _db!;
    }
    
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(path, version: _dbVersion, onCreate: onCreateDb, onUpgrade: onUpgradeDb);
    await _seedIfNeeded(_db!);
    return _db!;
  }

  static Future<void> _seedIfNeeded(Database db) async {
    if (!_mockMode) return;
    final estCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM estabelecimentos')) ?? 0;
    if (estCount == 0) {
      await db.insert('estabelecimentos', {
        'cnpj': '12345678000190',
        'razao_social': 'Padaria Central LTDA',
        'nome_fantasia': 'Padaria Central',
        'cnae': '4721102',
        'rua': 'Av. Brasil',
        'numero': '100',
        'bairro': 'Centro',
        'cep': '88330000',
        'cidade': 'Balneário Camboriú',
        'uf': 'SC',
        'telefone': '(47) 99999-0001',
        'email': 'contato@padariacentral.com',
        'responsavel': 'João da Silva',
        'cpf_responsavel': '00000000000',
        'risco': 'Baixo',
        'status_alvara': 'Regular',
        'status_sanitario': 'Regular',
        'grau_risco': 'Baixo',
        'atividade_principal': 'Padaria e confeitaria',
        'data_cadastro': '2026-03-10',
        'lat': -26.9900,
        'lng': -48.6350,
      });
      await db.insert('estabelecimentos', {
        'cnpj': '98765432000100',
        'razao_social': 'Restaurante Praia ME',
        'nome_fantasia': 'Restaurante Praia',
        'cnae': '5611201',
        'rua': 'Av. Atlântica',
        'numero': '2000',
        'bairro': 'Barra Sul',
        'cep': '88330001',
        'cidade': 'Balneário Camboriú',
        'uf': 'SC',
        'telefone': '(47) 99999-0002',
        'email': 'financeiro@restaurantepraia.com',
        'responsavel': 'Maria Oliveira',
        'cpf_responsavel': '11111111111',
        'risco': 'Médio',
        'status_alvara': 'Regular',
        'status_sanitario': 'Regular',
        'grau_risco': 'Médio',
        'atividade_principal': 'Restaurantes',
        'data_cadastro': '2026-03-12',
        'lat': -26.9955,
        'lng': -48.6332,
      });
      await db.insert('estabelecimentos', {
        'cnpj': '11223344000155',
        'razao_social': 'Laticínios BC Indústria',
        'nome_fantasia': 'Laticínios BC',
        'cnae': '1052000',
        'rua': 'Rua 1500',
        'numero': '50',
        'bairro': 'Nações',
        'cep': '88330002',
        'cidade': 'Balneário Camboriú',
        'uf': 'SC',
        'telefone': '(47) 99999-0003',
        'email': 'suporte@laticiniosbc.com',
        'responsavel': 'Carlos Souza',
        'cpf_responsavel': '22222222222',
        'risco': 'Alto',
        'status_alvara': 'Vencido',
        'status_sanitario': 'Irregular',
        'grau_risco': 'Alto',
        'atividade_principal': 'Fabricação de laticínios',
        'data_cadastro': '2026-03-08',
        'lat': -27.0042,
        'lng': -48.6401,
      });
    }

    final inspCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM inspecoes')) ?? 0;
    if (inspCount == 0) {
      await db.insert('inspecoes', {'tipo_auto': 'INT', 'estabelecimento_id': 1, 'data': '2026-03-20', 'hora': '09:30', 'status': 'PENDENTE'});
      await db.insert('inspecoes', {'tipo_auto': 'INF', 'estabelecimento_id': 2, 'data': '2026-03-18', 'hora': '14:10', 'status': 'CONCLUÍDA'});
      await db.insert('inspecoes', {'tipo_auto': 'COL', 'estabelecimento_id': 3, 'data': '2026-03-16', 'hora': '11:00', 'status': 'PENDENTE'});
    }

    final penCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM penalidades')) ?? 0;
    if (penCount == 0) {
      await db.insert('penalidades', {'descricao': 'Advertência', 'codigo_legal': 'Lei 6.437/77', 'valor': 0.0});
      await db.insert('penalidades', {'descricao': 'Multa', 'codigo_legal': 'Lei 6.437/77', 'valor': 1500.0});
      await db.insert('penalidades', {'descricao': 'Interdição', 'codigo_legal': 'Lei 6.437/77', 'valor': 0.0});
    }
  }

  static Future<List<Map<String, dynamic>>> listarInspecoesLocal() async {
    try {
      final db = await instance;
      return db.query('inspecoes', orderBy: 'data DESC');
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> listarAutosTermosLocal() async {
    try {
      final db = await instance;
      return db.query('autos_sanitarios', orderBy: 'data_hora DESC, data DESC, id DESC');
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> listarAutosSanitariosPendentesSync() async {
    try {
      final db = await instance;
      return db.query(
        'autos_sanitarios',
        where:
            '(status_sincronizacao IS NULL OR status_sincronizacao = ? OR status_sincronizacao IN (?, ?, ?))',
        whereArgs: ['', 'PENDENTE_SINCRONIZACAO', 'ENVIADO', 'ERRO'],
        orderBy: 'data_hora ASC, data ASC, id ASC',
      );
    } catch (_) {
      return [];
    }
  }

  static Future<int> atualizarAutoSanitario(int id, Map<String, dynamic> values) async {
    final db = await instance;
    return db.update('autos_sanitarios', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<String> nextNumeroAuto(String tipo) async {
    final year = DateTime.now().year.toString();
    final db = await instance;
    final res = await db.rawQuery('SELECT COUNT(*) AS c FROM autos_sanitarios WHERE tipo_auto = ? AND data LIKE ?', [tipo, '$year%']);
    final count = (res.first['c'] as int?) ?? 0;
    final next = count + 1;
    final numStr = next.toString().padLeft(4, '0');
    return '$tipo-$year-$numStr';
  }
}
