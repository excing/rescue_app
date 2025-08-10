import type { RequestHandler } from '@sveltejs/kit';
import { initializeFirebaseAdmin } from '$lib/firebase-admin';
import admin from 'firebase-admin';
import { proxy } from '$lib/utils/proxy';

// 初始化 Firebase Admin
initializeFirebaseAdmin();

/**
 * 获取所有集合列表
 * GET /api/firestore/collections
 */
export const GET: RequestHandler = async ({ url }) => {
  try {
    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.get(url.pathname + url.search);
    if (proxyResp) return proxyResp;

    const db = admin.firestore();

    // 获取根级别的集合
    const collections = await db.listCollections();
    const collectionNames = collections.map(col => col.id);

    return new Response(JSON.stringify({
      success: true,
      data: {
        collections: collectionNames,
        count: collectionNames.length
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('获取集合列表失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '获取集合列表失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};

/**
 * 创建新集合（通过添加第一个文档）
 * POST /api/firestore/collections
 */
export const POST: RequestHandler = async ({ request, url }) => {
  try {
    const { collectionName, documentData, documentId } = await request.json();

    if (!collectionName || !documentData) {
      return new Response(JSON.stringify({
        success: false,
        error: '缺少集合名称或文档数据'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.post(url.pathname + url.search, {
      body: JSON.stringify({ collectionName, documentData, documentId })
    });
    if (proxyResp) return proxyResp;

    const db = admin.firestore();

    // 添加时间戳
    const dataWithTimestamp = {
      ...documentData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    let docRef;
    if (documentId) {
      // 使用指定的文档 ID
      docRef = db.collection(collectionName).doc(documentId);
      await docRef.set(dataWithTimestamp);
    } else {
      // 自动生成文档 ID
      docRef = await db.collection(collectionName).add(dataWithTimestamp);
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        collectionName,
        documentId: docRef.id,
        message: '集合创建成功'
      }
    }), {
      status: 201,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('创建集合失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '创建集合失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};

/**
 * 删除集合（删除集合中的所有文档）
 * DELETE /api/firestore/collections
 */
export const DELETE: RequestHandler = async ({ request, url }) => {
  try {
    const { collectionName, batchSize = 100 } = await request.json();

    if (!collectionName) {
      return new Response(JSON.stringify({
        success: false,
        error: '缺少集合名称'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.delete(url.pathname + url.search, {
      body: JSON.stringify({ collectionName, batchSize })
    });
    if (proxyResp) return proxyResp;

    const db = admin.firestore();
    const collectionRef = db.collection(collectionName);

    // 批量删除文档
    let deletedCount = 0;
    let hasMore = true;

    while (hasMore) {
      const snapshot = await collectionRef.limit(batchSize).get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      deletedCount += snapshot.docs.length;

      // 如果返回的文档数量少于批次大小，说明已经删除完毕
      if (snapshot.docs.length < batchSize) {
        hasMore = false;
      }
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        collectionName,
        deletedCount,
        message: `集合 ${collectionName} 删除成功，共删除 ${deletedCount} 个文档`
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('删除集合失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '删除集合失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};
