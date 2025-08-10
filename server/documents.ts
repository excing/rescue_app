import type { RequestHandler } from '@sveltejs/kit';
import { initializeFirebaseAdmin } from '$lib/firebase-admin';
import admin from 'firebase-admin';
import { proxy } from '$lib/utils/proxy';

// 初始化 Firebase Admin
initializeFirebaseAdmin();

/**
 * 获取文档列表或单个文档
 * GET /api/firestore/documents?collection=xxx&document=xxx&limit=10&orderBy=createdAt&orderDirection=desc
 */
export const GET: RequestHandler = async ({ url }) => {
  try {
    const collection = url.searchParams.get('collection');
    const documentId = url.searchParams.get('document');
    const limit = parseInt(url.searchParams.get('limit') || '10');
    const orderBy = url.searchParams.get('orderBy') || 'createdAt';
    const orderDirection = url.searchParams.get('orderDirection') || 'desc';
    const startAfter = url.searchParams.get('startAfter');

    if (!collection) {
      return new Response(JSON.stringify({
        success: false,
        error: '缺少集合名称参数'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.get(url.pathname + url.search);
    if (proxyResp) return proxyResp;

    const db = admin.firestore();
    const collectionRef = db.collection(collection);

    if (documentId) {
      // 获取单个文档
      const docRef = collectionRef.doc(documentId);
      const doc = await docRef.get();

      if (!doc.exists) {
        return new Response(JSON.stringify({
          success: false,
          error: '文档不存在'
        }), {
          status: 404,
          headers: {
            'Content-Type': 'application/json'
          }
        });
      }

      return new Response(JSON.stringify({
        success: true,
        data: {
          id: doc.id,
          data: doc.data(),
          exists: doc.exists,
          createTime: doc.createTime?.toDate(),
          updateTime: doc.updateTime?.toDate()
        }
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    } else {
      // 获取文档列表
      let query = collectionRef.orderBy(orderBy, orderDirection as any).limit(limit);

      // 分页支持
      if (startAfter) {
        const startAfterDoc = await collectionRef.doc(startAfter).get();
        if (startAfterDoc.exists) {
          query = query.startAfter(startAfterDoc);
        }
      }

      const snapshot = await query.get();
      const documents = snapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data(),
        createTime: doc.createTime?.toDate(),
        updateTime: doc.updateTime?.toDate()
      }));

      return new Response(JSON.stringify({
        success: true,
        data: {
          documents,
          count: documents.length,
          hasMore: documents.length === limit,
          lastDocumentId: documents.length > 0 ? documents[documents.length - 1].id : null
        }
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

  } catch (error: any) {
    console.error('获取文档失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '获取文档失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};

/**
 * 创建或更新文档
 * POST /api/firestore/documents
 */
export const POST: RequestHandler = async ({ request, url }) => {
  try {
    const { collection, documentId, data, merge = false } = await request.json();

    if (!collection || !data) {
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
      body: JSON.stringify({ collection, documentId, data, merge })
    });
    if (proxyResp) return proxyResp;

    const db = admin.firestore();
    const collectionRef = db.collection(collection);

    // 添加时间戳
    const dataWithTimestamp = {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // 如果是新文档，添加创建时间
    if (!documentId || merge === false) {
      dataWithTimestamp.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    let docRef;
    let isNew = false;

    if (documentId) {
      // 使用指定的文档 ID
      docRef = collectionRef.doc(documentId);

      if (merge) {
        // 合并更新
        await docRef.set(dataWithTimestamp, { merge: true });
      } else {
        // 完全替换
        await docRef.set(dataWithTimestamp);
        isNew = true;
      }
    } else {
      // 自动生成文档 ID
      docRef = await collectionRef.add(dataWithTimestamp);
      isNew = true;
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        collection,
        documentId: docRef.id,
        isNew,
        message: isNew ? '文档创建成功' : '文档更新成功'
      }
    }), {
      status: isNew ? 201 : 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('创建/更新文档失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '创建/更新文档失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};

/**
 * 更新文档
 * PUT /api/firestore/documents
 */
export const PUT: RequestHandler = async ({ request, url }) => {
  try {
    const { collection, documentId, data, merge = true } = await request.json();

    if (!collection || !documentId || !data) {
      return new Response(JSON.stringify({
        success: false,
        error: '缺少集合名称、文档ID或更新数据'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.put(url.pathname + url.search, {
      body: JSON.stringify({ collection, documentId, data, merge })
    });
    if (proxyResp) return proxyResp;

    const db = admin.firestore();
    const docRef = db.collection(collection).doc(documentId);

    // 检查文档是否存在
    const doc = await docRef.get();
    if (!doc.exists) {
      return new Response(JSON.stringify({
        success: false,
        error: '文档不存在'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 添加更新时间戳
    const dataWithTimestamp = {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (merge) {
      await docRef.update(dataWithTimestamp);
    } else {
      await docRef.set(dataWithTimestamp, { merge: false });
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        collection,
        documentId,
        message: '文档更新成功'
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('更新文档失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '更新文档失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};

/**
 * 删除文档
 * DELETE /api/firestore/documents
 */
export const DELETE: RequestHandler = async ({ request, url }) => {
  try {
    const { collection, documentId } = await request.json();

    if (!collection || !documentId) {
      return new Response(JSON.stringify({
        success: false,
        error: '缺少集合名称或文档ID'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    // 在开发环境中使用代理请求
    const proxyResp = await proxy.json.delete(url.pathname + url.search, {
      body: JSON.stringify({ collection, documentId })
    });
    if (proxyResp) return proxyResp;

    const db = admin.firestore();
    const docRef = db.collection(collection).doc(documentId);

    // 检查文档是否存在
    const doc = await docRef.get();
    if (!doc.exists) {
      return new Response(JSON.stringify({
        success: false,
        error: '文档不存在'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }

    await docRef.delete();

    return new Response(JSON.stringify({
      success: true,
      data: {
        collection,
        documentId,
        message: '文档删除成功'
      }
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error: any) {
    console.error('删除文档失败:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || '删除文档失败'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
};
